import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:share_plus/share_plus.dart';
import 'package:socialv/main.dart';
import 'package:socialv/models/posts/get_post_likes_model.dart';
import 'package:socialv/models/posts/post_model.dart';
import 'package:socialv/models/reactions/reactions_count_model.dart';
import 'package:socialv/network/rest_apis.dart';
import 'package:socialv/screens/blockReport/components/show_report_dialog.dart';
import 'package:socialv/screens/blog/screens/blog_detail_screen.dart';
import 'package:socialv/screens/groups/screens/group_detail_screen.dart';
import 'package:socialv/screens/membership/screens/membership_plans_screen.dart';
import 'package:socialv/screens/post/components/hidden_post_component.dart';
import 'package:socialv/screens/post/components/like_button_widget.dart';
import 'package:socialv/screens/post/components/popup_menu_button_component.dart';
import 'package:socialv/screens/post/components/post_likes_component.dart';
import 'package:socialv/screens/post/components/post_media_component.dart';
import 'package:socialv/screens/post/components/post_reaction_component.dart';
import 'package:socialv/screens/post/components/quick_view_post_widget.dart';
import 'package:socialv/screens/post/components/reaction_button_widget.dart';
import 'package:socialv/screens/post/screens/comment_screen.dart';
import 'package:socialv/screens/post/screens/single_post_screen.dart';
import 'package:socialv/screens/profile/screens/member_profile_screen.dart';
import 'package:socialv/utils/cached_network_image.dart';
import 'package:socialv/utils/overlay_handler.dart';

import '../../../utils/app_constants.dart';
import 'post_content_component.dart';

// ignore: must_be_immutable
class PostComponent extends StatefulWidget {
  final PostModel post;
  final VoidCallback? callback;
  final VoidCallback? commentCallback;
  int? count;
  final bool fromGroup;
  final bool fromProfile;
  final bool fromFavourites;
  final int? groupId;
  final bool showHidePostOption;
  final bool childPost;
  final Color? color;

  PostComponent({
    required this.post,
    this.callback,
    this.count,
    this.fromGroup = false,
    this.groupId,
    this.showHidePostOption = false,
    this.childPost = false,
    this.color,
    this.fromProfile = false,
    this.commentCallback,
    this.fromFavourites = false,
    super.key,
  });

  @override
  State<PostComponent> createState() => _PostComponentState();
}

class _PostComponentState extends State<PostComponent> {
  OverlayHandler _overlayHandler = OverlayHandler();
  PageController pageController = PageController();

  List<GetPostLikesModel> postLikeList = [];
  List<Reactions> postReactionList = [];
  bool isLiked = false;
  int postLikeCount = 0;
  int index = 0;

  bool? isReacted;
  bool isPostHidden = false;
  int postReactionCount = 0;
  bool notify = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    isPostHidden = false;
    postLikeList = widget.post.usersWhoLiked.validate();
    postLikeCount = widget.post.likeCount.validate();
    isLiked = widget.post.isLiked.validate() == 1;
    postReactionList = widget.post.reactions.validate();
    isReacted = widget.post.curUserReaction != null;
    postReactionCount = widget.post.reactionCount.validate();
    setState(() {});
  }

  Future<void> postReaction({bool addReaction = false, int? reactionID, bool fromQuickView = false}) async {
    ifNotTester(() async {
      if (addReaction) {
        if (postReactionList.length < 3 && isReacted.validate()) {
          if (postReactionList.any((element) => element.user!.id.validate().toString() == userStore.loginUserId)) {
            int index = postReactionList.indexWhere((element) => element.user!.id.validate().toString() == userStore.loginUserId);
            postReactionList[index].id = reactionID.validate().toString();
            postReactionList[index].icon = appStore.reactions.firstWhere((element) => element.id == reactionID.validate().toString().validate()).imageUrl.validate();
            postReactionList[index].reaction = appStore.reactions.firstWhere((element) => element.id == reactionID.validate().toString().validate()).name.validate();
          } else {
            postReactionList.add(
              Reactions(
                id: reactionID.validate().toString(),
                icon: appStore.reactions.firstWhere((element) => element.id == reactionID.validate().toString().validate()).imageUrl.validate(),
                reaction: appStore.reactions.firstWhere((element) => element.id == reactionID.validate().toString().validate()).name.validate(),
                user: ReactedUser(
                  id: userStore.loginUserId.validate().toInt(),
                  displayName: userStore.loginFullName,
                ),
              ),
            );
            postReactionCount++;
          }
        }
        widget.post.curUserReaction = Reactions(
          id: reactionID.validate().toString(),
          icon: appStore.reactions.firstWhere((element) => element.id == reactionID.validate().toString().validate()).imageUrl.validate(),
          reaction: appStore.reactions.firstWhere((element) => element.id == reactionID.validate().toString().validate()).name.validate(),
          user: ReactedUser(
            id: userStore.loginUserId.validate().toInt(),
            displayName: userStore.loginFullName,
          ),
        );
        notify = true;
        setState(() {});
        await addPostReaction(id: widget.post.activityId.validate(), reactionId: reactionID.validate(), isComments: false).then((value) {
          if (fromQuickView) widget.callback!.call();
        }).catchError((e) {
          log('Error: ${e.toString()}');
        });
      } else {
        widget.post.curUserReaction = null;
        postReactionList.removeWhere((element) => element.user!.id.validate().toString() == userStore.loginUserId);

        postReactionCount--;
        notify = false;
        setState(() {});
        await deletePostReaction(id: widget.post.activityId.validate(), isComments: false).then((value) {
          if (fromQuickView) widget.callback!.call();
        }).catchError((e) {
          log('Error: ${e.toString()}');
        });
      }
    });
  }

  Future<void> postLike() async {
    ifNotTester(() async {
      isLiked = !isLiked;

      if (isLiked) {
        if (postLikeList.length < 3 && isLiked) {
          postLikeList.add(GetPostLikesModel(
            userId: userStore.loginUserId,
            userAvatar: userStore.loginAvatarUrl,
            userName: userStore.loginFullName,
          ));
        }
        postLikeCount++;
        setState(() {});

        await likePost(postId: widget.post.activityId.validate()).then((value) {
          //
        }).catchError((e) {
          log('Error: ${e.toString()}');
        });
      } else {
        if (postLikeList.length <= 3) {
          postLikeList.removeWhere((element) => element.userId == userStore.loginUserId);
        }
        postLikeCount--;
        setState(() {});
        await likePost(postId: widget.post.activityId.validate()).then((value) {
          //
        }).catchError((e) {
          log('Error: ${e.toString()}');
        });
      }
    });
  }

  Future<void> onHidePost() async {
    ifNotTester(() async {
      isPostHidden = !isPostHidden;

      if (isPostHidden) {
        toast(language.thisPostIsNowHidden);
      } else {
        toast(language.postUnhiddenToast);
      }

      setState(() {});
      await hidePost(id: widget.post.activityId.validate()).then((value) {
        //
      }).catchError((e) {
        log("Error:" + e.toString());
      });
    });
  }

  Future<void> onReportPost() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.white),
              ),
              8.height,
              Container(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                ),
                child: ShowReportDialog(
                  isPostReport: true,
                  postId: widget.post.activityId.validate(),
                  userId: widget.post.userId.validate(),
                ),
              ).expand(),
            ],
          ),
        );
      },
    );
  }

  Future<void> onDeletePost() async {
    showConfirmDialogCustom(
      context,
      onAccept: (c) {
        ifNotTester(() {
          appStore.setLoading(true);

          deletePost(postId: widget.post.activityId.validate()).then((value) {
            appStore.setLoading(false);
            toast(language.postDeleted);
            widget.callback?.call();
            setState(() {});
          }).catchError((e) {
            appStore.setLoading(false);
            toast(e.toString());
          });
        });
      },
      dialogType: DialogType.CONFIRMATION,
      title: language.deletePostConfirmation,
      positiveText: language.remove,
    );
  }

  Future<void> onUnfriend() async {
    showConfirmDialogCustom(
      context,
      onAccept: (c) async {
        ifNotTester(() async {
          appStore.setLoading(true);
          await removeExistingFriendConnection(friendId: widget.post.userId.toString(), passRequest: true).then((value) {
            appStore.setLoading(false);
            widget.callback?.call();
            setState(() {});
          }).catchError((e) {
            appStore.setLoading(false);
            log(e.toString());
          });
        });
      },
      dialogType: DialogType.CONFIRMATION,
      title: language.unfriendConfirmation,
      positiveText: language.remove,
    );
  }

  Future<void> onViewBlogPost() async {
    if (widget.post.blogId != null) {
      appStore.setLoading(true);
      await wpPostById(postId: widget.post.blogId.validate()).then((value) {
        appStore.setLoading(false);
        if (value.is_restricted.validate()) {
          MembershipPlansScreen().launch(context);
        } else {
          BlogDetailScreen(blogId: widget.post.blogId.validate(), data: value).launch(context);
        }
      }).catchError((e) {
        toast(language.canNotViewPost);
        appStore.setLoading(false);
      });
    } else {
      toast(language.canNotViewPost);
    }
  }

  Future<void> onFavorites() async {
    ifNotTester(() {
      if (widget.post.isFavorites == 0) {
        widget.post.isFavorites = 1;
        toast(language.postAddedToFavorite);
      } else {
        widget.post.isFavorites = 0;
        toast(language.postRemovedFromFavorite);
      }
      Map<String, dynamic> request = {"is_favorite": widget.post.isFavorites};

      favoriteActivity(request: request, activityId: widget.post.activityId.validate().toInt()).then((value) {
        if (widget.post.isFavorites == 0 && widget.fromFavourites) widget.commentCallback?.call();
      }).catchError((e) {
        log('Error: ${e.toString()}');
      });
    });
  }

  Future<void> onPinned() async {
    ifNotTester(() {
      Map<String, dynamic> request = {
        "pin_activity": widget.post.isPinned == 1 ? 0 : 1,
      };

      if (widget.fromGroup) request.putIfAbsent('group_id', () => widget.groupId);
      if (widget.fromFavourites)
        request.putIfAbsent('screen', () => "favorites");
      else if (widget.fromGroup)
        request.putIfAbsent('screen', () => "groups");
      else if (widget.fromProfile)
        request.putIfAbsent('screen', () => "timeline");
      else
        request.putIfAbsent('screen', () => "newsfeed");
      pinActivity(activityId: widget.post.activityId.validate(), request: request).catchError((e) {
        log('Error: ${e.toString()}');
      });
      if (widget.post.isPinned == 0) {
        widget.post.isPinned = 1;
        toast(language.pinned);
      } else {
        widget.post.isPinned = 0;
        toast(language.unpinned);
      }
      setState(() {});
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void dispose() {
    _overlayHandler.removeOverlay(context);
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count == 0) {
      init();
      widget.count = widget.count.validate() + 1;
    }

    if (!isPostHidden) {
      return GestureDetector(
        onTap: () {
          if (widget.post.type.validate() == PostActivityType.newBlogPost) {
            onViewBlogPost();
          } else {
            SinglePostScreen(postId: widget.post.activityId.validate()).launch(context).then((value) {
              if (value ?? false) widget.callback?.call();
            });
          }
        },
        onPanEnd: (s) {
          if (!widget.childPost.validate()) _overlayHandler.removeOverlay(context);
        },
        onLongPress: () {
          if (!widget.childPost.validate())
            _overlayHandler.insertOverlay(
              context,
              OverlayEntry(
                builder: (context) {
                  return QuickViewPostWidget(
                    postModel: widget.post,
                    isPostLiked: isLiked,
                    onPostLike: () async {
                      postLike();
                      widget.callback!.call();
                    },
                    onPostReacted: (id) {
                      isReacted = true;
                      postReaction(reactionID: id, addReaction: true);
                    },
                    onReactionRemoved: () {
                      isReacted = false;
                      postReaction(reactionID: widget.post.curUserReaction!.id.toInt(), addReaction: false);
                    },
                    pageIndex: index,
                    isPostReacted: isReacted!,
                  );
                },
              ),
            );
        },
        onLongPressEnd: (details) {
          if (!widget.childPost.validate()) _overlayHandler.removeOverlay(context);
        },
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(borderRadius: radius(commonRadius), color: widget.color ?? context.cardColor),
          child: Observer(
              warnWhenNoObservables: false,
              builder: (context) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        cachedImage(
                          widget.post.userImage.validate(),
                          height: 40,
                          width: 40,
                          fit: BoxFit.cover,
                        ).cornerRadiusWithClipRRect(100),
                        12.width,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '${widget.post.userName.validate()}',
                                  style: boldTextStyle(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ).flexible(flex: 1),
                                if (widget.post.isUserVerified.validate() == 1) Image.asset(ic_tick_filled, width: 18, height: 18, color: blueTickColor).paddingSymmetric(horizontal: 4),
                              ],
                            ),
                            4.height,
                            Text(convertToAgo(widget.post.dateRecorded.validate()), style: secondaryTextStyle()),
                          ],
                        ).expand(),
                        if (widget.post.isPinned == 1) Image.asset(ic_push_pin, height: 18, width: 18, color: context.primaryColor),
                        if (!widget.childPost.validate())
                          PopUpMenuButtonComponent(
                            post: widget.post,
                            onReportPost: () => onReportPost(),
                            onFavorites: () => onFavorites(),
                            onDeletePost: () => onDeletePost(),
                            onPinned: () => onPinned(),
                            onHidePost: () => onHidePost(),
                            callback: () => widget.callback!.call(),
                            groupId: widget.groupId,
                            showHidePostOption: widget.showHidePostOption,
                          ),
                      ],
                    ).paddingOnly(left: 8, top: 8, right: 8).onTap(() {
                      if (!widget.fromProfile) MemberProfileScreen(memberId: widget.post.userId.validate()).launch(context);
                    }, borderRadius: radius(8)),
                    8.height,
                    if (!widget.fromGroup)
                      if (widget.post.postIn == Component.groups && widget.post.groupName.validate().isNotEmpty)
                        InkWell(
                          onTap: () {
                            if (widget.post.groupId != 0) {
                              if (pmpStore.viewSingleGroup) {
                                GroupDetailScreen(groupId: widget.post.groupId.validate()).launch(context);
                              } else {
                                MembershipPlansScreen().launch(context);
                              }
                            }
                          },
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(text: '${widget.post.userName.validate()} ', style: boldTextStyle(fontFamily: fontFamily, size: 14)),
                                TextSpan(text: '${language.postedAnUpdateInTheGroup} ', style: primaryTextStyle(fontFamily: fontFamily, size: 14)),
                                TextSpan(text: '${widget.post.groupName.validate()} ', style: boldTextStyle(fontFamily: fontFamily, size: 14)),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.start,
                          ).paddingSymmetric(horizontal: 8),
                        ),
                    Divider(),
                    PostContentComponent(
                      postContent: widget.post.content,
                      hasMentions: widget.post.hasMentions == 1,
                      postType: widget.post.type,
                      blogId: widget.post.blogId,
                      contentObject: widget.post.contentObject,
                    ),
                    PostMediaComponent(
                      mediaTitle: widget.post.userName.validate(),
                      mediaType: widget.post.mediaType.validate(),
                      mediaList: widget.post.medias.validate(),
                      onPageChange: (i) {
                        index = i;
                      },
                    ),
                    if (widget.post.type == PostActivityType.activityShare && widget.post.childPost != null)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: PostComponent(post: widget.post.childPost!, childPost: true, color: context.scaffoldBackgroundColor),
                      ),
                    if (widget.childPost.validate())
                      TextButton(
                        onPressed: () {
                          SinglePostScreen(postId: widget.post.activityId.validate()).launch(context).then((value) {
                            if (value ?? false) widget.callback?.call();
                          });
                        },
                        child: Text(language.viewPost, style: primaryTextStyle(color: context.primaryColor)),
                      ),
                    if (!widget.childPost.validate())
                      Observer(
                        builder: (context) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  if (appStore.isReactionEnable)
                                    if (appStore.reactions.validate().isNotEmpty)
                                      ReactionButton(
                                        isReacted: notify,
                                        isComments: false,
                                        currentUserReaction: widget.post.curUserReaction,
                                        onReacted: (id) {
                                          isReacted = true;
                                          postReaction(addReaction: true, reactionID: id);
                                        },
                                        onReactionRemoved: () {
                                          isReacted = false;
                                          postReaction(addReaction: false);
                                        },
                                      ).paddingOnly(right: 6, bottom: 8, top: 8)
                                    else
                                      Offstage()
                                  else
                                    LikeButtonWidget(
                                      key: ValueKey(isLiked),
                                      onPostLike: () {
                                        postLike();
                                      },
                                      isPostLiked: isLiked,
                                    ).paddingOnly(right: 6, bottom: 8, top: 8),
                                  Image.asset(
                                    ic_chat,
                                    height: 22,
                                    width: 22,
                                    fit: BoxFit.cover,
                                    color: context.iconColor,
                                  ).paddingOnly(right: 4, bottom: 8, top: 8, left: 6).onTap(() {
                                    if (!appStore.isLoading) {
                                      CommentScreen(postId: widget.post.activityId.validate()).launch(context).then((value) {
                                        if (value ?? false) widget.commentCallback?.call();
                                      });
                                    }
                                  }, highlightColor: Colors.transparent, splashColor: Colors.transparent),
                                  Image.asset(
                                    ic_send,
                                    height: 22,
                                    width: 22,
                                    fit: BoxFit.cover,
                                    color: context.iconColor,
                                  ).paddingAll(4).onTap(() {
                                    if (!appStore.isLoading) {
                                      String saveUrl = "$DOMAIN_URL/activity/${widget.post.activityId}";
                                      Share.shareUri(Uri.parse(saveUrl.trim()));
                                    }
                                  }, splashColor: Colors.transparent, highlightColor: Colors.transparent),
                                ],
                              ),
                              if (appStore.displayPostCommentsCount)
                                TextButton(
                                  onPressed: () {
                                    CommentScreen(
                                      postId: widget.post.activityId.validate(),
                                      callback: () {
                                        widget.commentCallback?.call();
                                      },
                                    ).launch(context);
                                  },
                                  child: widget.post.commentCount.validate() > 0
                                      ? Text('${widget.post.commentCount} ${widget.post.commentCount.validate() > 1 ? language.comments : language.comment}', style: secondaryTextStyle())
                                      : Text(
                                          language.noCommentsYet,
                                          style: secondaryTextStyle(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                ),
                            ],
                          ).paddingSymmetric(horizontal: 8);
                        },
                      ),
                    if (!widget.childPost.validate())
                      if (appStore.isReactionEnable)
                        ThreeReactionComponent(
                          isComments: false,
                          id: widget.post.activityId.validate(),
                          postReactionCount: postReactionCount,
                          postReactionList: postReactionList,
                        ).paddingOnly(left: 8, bottom: 8)
                      else
                        PostLikesComponent(
                          postLikeList: postLikeList,
                          postId: widget.post.activityId.validate(),
                          postLikeCount: postLikeCount,
                        ),
                  ],
                );
              }),
        ),
      );
    } else {
      return HiddenPostComponent(
        isFriend: widget.post.isFriend.validate() == 1,
        userName: widget.post.userName.validate(),
        onReportPost: () => onReportPost(),
        onUndo: () => onHidePost(),
        onUnfriend: () => onUnfriend(),
      );
    }
  }
}
