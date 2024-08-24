import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:socialv/main.dart';
import 'package:socialv/models/members/friend_request_model.dart';
import 'package:socialv/network/rest_apis.dart';
import 'package:socialv/screens/home/screens/members_list_screen.dart';
import 'package:socialv/screens/membership/screens/membership_plans_screen.dart';
import 'package:socialv/screens/profile/screens/member_profile_screen.dart';
import 'package:socialv/utils/cached_network_image.dart';

import '../../../utils/app_constants.dart';

class SuggestedUserComponent extends StatefulWidget {
  const SuggestedUserComponent({Key? key}) : super(key: key);

  @override
  State<SuggestedUserComponent> createState() => _SuggestedUserComponentState();
}

class _SuggestedUserComponentState extends State<SuggestedUserComponent> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> getDetails() async {
    await getDashboardDetails().then((value) {
      appStore.suggestedUserList = value.suggestedUser.validate();
    }).catchError(onError);
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) {
        if (appStore.suggestedUserList.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(language.suggestedUsers, style: boldTextStyle()),
                  if (appStore.suggestedUserList.length == 5)
                    TextButton(
                        onPressed: () {
                          if (pmpStore.memberDirectory) {
                            MembersListScreen(isSuggested: true).launch(context);
                          } else {
                            MembershipPlansScreen().launch(context);
                          }
                        },
                        child: Text(
                          language.viewAll,
                          style: primaryTextStyle(color: context.primaryColor),
                        ))
                ],
              ).paddingSymmetric(horizontal: 8),
              if (appStore.suggestedUserList.length != 5) 16.height,
              HorizontalList(
                crossAxisAlignment: WrapCrossAlignment.start,
                wrapAlignment: WrapAlignment.start,
                padding: EdgeInsets.symmetric(horizontal: 8),
                spacing: 12,
                itemCount: appStore.suggestedUserList.length,
                itemBuilder: (ctx, index) {
                  FriendRequestModel member = appStore.suggestedUserList[index];

                  return InkWell(
                    onTap: () {
                      MemberProfileScreen(memberId: member.userId.validate()).launch(context);
                    },
                    radius: commonRadius,
                    child: Container(
                      decoration: BoxDecoration(color: context.cardColor, borderRadius: radius(commonRadius)),
                      height: 250,
                      width: 200,
                      padding: EdgeInsets.all(16),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Column(
                            children: [
                              6.height,
                              cachedImage(member.userImage.validate(), height: 100, width: 100).cornerRadiusWithClipRRect(50),
                              8.height,
                              Marquee(
                                child: Text(member.userName.validate(), style: primaryTextStyle()),
                              ),
                              Text('@' + member.userMentionName.validate(), style: secondaryTextStyle()).expand(),
                              AppButton(
                                onTap: () async {
                                  ifNotTester(() async {
                                    if (!member.isRequested.validate()) {
                                      if (pmpStore.sendFriendRequest) {
                                        member.isRequested = !member.isRequested.validate();
                                        setState(() {});
                                        Map request = {"initiator_id": userStore.loginUserId, "friend_id": member.userId.validate()};
                                        await requestNewFriend(request).then((value) async {
                                          getDetails();
                                        }).catchError((e) {
                                          member.isRequested = !member.isRequested.validate();
                                          setState(() {});
                                        });
                                      } else {
                                        MembershipPlansScreen().launch(context);
                                      }
                                    } else {
                                      member.isRequested = !member.isRequested.validate();
                                      setState(() {});
                                      await removeExistingFriendConnection(friendId: member.userId.validate().toString(), passRequest: true).then((value) {
                                        getDetails();
                                      }).catchError((e) {
                                        member.isRequested = !member.isRequested.validate();
                                        setState(() {});
                                      });
                                    }
                                  });
                                },
                                text: member.isRequested.validate() ? language.requested : language.addFriends,
                                textStyle: secondaryTextStyle(color: member.isRequested.validate() ? context.iconColor : Colors.white),
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                elevation: 0,
                                color: member.isRequested.validate() ? context.scaffoldBackgroundColor : context.primaryColor,
                              )
                            ],
                          ),
                          Positioned(
                            child: InkWell(
                              onTap: () {
                                ifNotTester(() async {
                                  appStore.suggestedUserList.removeAt(index);
                                  setState(() {});

                                  log('member.userId.validate(): ${member.userId.validate()}');
                                  await removeSuggestedUser(userId: member.userId.validate()).then((value) {
                                    getDetails();
                                  }).catchError(onError);
                                });
                              },
                              child: Icon(Icons.cancel_outlined, color: context.primaryColor),
                            ),
                            right: 0,
                            top: 0,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
            ],
          ).paddingSymmetric(vertical: 8);
        } else {
          return Offstage();
        }
      },
    );
  }
}
