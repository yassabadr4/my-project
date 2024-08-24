import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:socialv/main.dart';
import 'package:socialv/network/rest_apis.dart';
import 'package:socialv/screens/auth/components/successful_activation_dialog.dart';
import 'package:socialv/screens/auth/components/verify_auth_key_component.dart';
import 'package:socialv/screens/dashboard_screen.dart';
import 'package:socialv/screens/profile/components/expansion_body.dart';
import 'package:socialv/screens/profile/components/profile_field_component.dart';

import '../../../utils/app_constants.dart';

class SignUpComponent extends StatefulWidget {
  final VoidCallback? callback;
  final String? deepLink;

  SignUpComponent({this.callback, this.deepLink});

  @override
  State<SignUpComponent> createState() => _SignUpComponentState();
}

class _SignUpComponentState extends State<SignUpComponent> {
  List<String> message = [];
  final signupFormKey = GlobalKey<FormState>();

  TextEditingController userNameCont = TextEditingController();
  TextEditingController fullNameCont = TextEditingController();
  TextEditingController passwordCont = TextEditingController();
  TextEditingController emailCont = TextEditingController();
  TextEditingController contactCont = TextEditingController();

  FocusNode userName = FocusNode();
  FocusNode fullName = FocusNode();
  FocusNode password = FocusNode();
  FocusNode email = FocusNode();
  FocusNode contact = FocusNode();

  bool agreeTNC = false;

  @override
  void initState() {
    super.initState();
  }

  void register() async {
    if (signupFormKey.currentState!.validate()) {
      signupFormKey.currentState!.save();
      hideKeyboard(context);
      appStore.setLoading(true);

      if (group.fields.validate().any((element) => element.value.validate().isNotEmpty)) {
        if (isDetailChange) {
          Map request = {
            "user_login": userNameCont.text.validate(),
            "user_name": fullNameCont.text.validate(),
            "user_email": emailCont.text.validate(),
            "password": passwordCont.text.validate(),
          };

          await createUser(request).then((value) async {
            appStore.setLoading(false);
            if (appStore.isAuthVerificationEnable) {
              toast('Please check your inbox for account activation key');
              showVerificationDialog();
            } else {
              login();
            }
          }).catchError((e) {
            appStore.setLoading(false);
            String errorResponseMessage = '';
            if (e is String) {
              errorResponseMessage = e;
            } else {
              e.forEach((data) {
                errorResponseMessage = errorResponseMessage + data;
              });
            }
            toast(errorResponseMessage);
          });
        }
      } else {
        toast(language.enterValidDetails);
      }
    }
  }

  Future<void> login() async {
    appStore.setLoading(true);
    Map request = {
      Users.username: userNameCont.text.validate(),
      Users.password: passwordCont.text.validate(),
    };

    await loginUser(request: request, isSocialLogin: false).then((value) async {
      userStore.setPassword(passwordCont.text.validate());

      await updateProfileFields(request: group.toJson()).then((value) {
        widget.callback?.call();
      }).catchError((e) {
        appStore.setLoading(false);
        toast(e.toString());
      });

      if (widget.deepLink.validate().isNotEmpty) {
        handleDeepLinking(context: context, deepLink: widget.deepLink.validate());
      } else {
        push(DashboardScreen(), isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
      }
    }).catchError((e) {
      appStore.setLoading(false);
      toast(e.toString());
    });
  }

  Future<void> showVerificationDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return VerifyAuthKeyComponent(
          onSubmit: (text) {
            verify(text);
          },
          callback: () {
            widget.callback?.call;
          },
        );
      },
    );
  }

  Future<void> verify(String authKey) async {
    appStore.setLoading(true);

    verifyKey(key: authKey).then((value) {
      appStore.setLoading(false);
      if (value.isActivated != null && value.isActivated == 1) {
        if (signupFormKey.currentState!.validate()) {
          signupFormKey.currentState!.save();
          hideKeyboard(context);

          login();
        } else {
          showSuccessfulActivationDialog().then((value) {
            widget.callback?.call();
          });
        }
      } else {
        toast(value.message);
      }
    }).catchError((e) {
      appStore.setLoading(false);
      toast(e.toString(), print: true);
    });
  }

  Future<void> showSuccessfulActivationDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SuccessfulActivationDialog();
      },
    ).then((value) {});
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (_) => Container(
        width: context.width(),
        color: context.cardColor,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              16.height,
              Text(language.helloUser, style: boldTextStyle(size: 24)).paddingSymmetric(horizontal: 16),
              8.height,
              Text(language.createYourAccountFor, style: secondaryTextStyle(weight: FontWeight.w500)).paddingSymmetric(horizontal: 16),
              Form(
                key: signupFormKey,
                child: Container(
                  child: Column(
                    children: [
                      30.height,
                      AppTextField(
                        enabled: !appStore.isLoading,
                        controller: userNameCont,
                        nextFocus: fullName,
                        focus: userName,
                        textFieldType: TextFieldType.USERNAME,
                        textStyle: boldTextStyle(),
                        decoration: inputDecoration(
                          context,
                          label: language.username,
                          labelStyle: secondaryTextStyle(weight: FontWeight.w600),
                        ),
                      ).paddingSymmetric(horizontal: 16),
                      8.height,
                      AppTextField(
                        enabled: !appStore.isLoading,
                        controller: fullNameCont,
                        nextFocus: email,
                        focus: fullName,
                        textFieldType: TextFieldType.NAME,
                        textStyle: boldTextStyle(),
                        decoration: inputDecoration(
                          context,
                          label: language.fullName,
                          labelStyle: secondaryTextStyle(weight: FontWeight.w600),
                        ),
                      ).paddingSymmetric(horizontal: 16),
                      8.height,
                      AppTextField(
                        enabled: !appStore.isLoading,
                        controller: emailCont,
                        nextFocus: password,
                        focus: email,
                        textFieldType: TextFieldType.EMAIL,
                        textStyle: boldTextStyle(),
                        decoration: inputDecoration(
                          context,
                          label: language.yourEmail,
                          labelStyle: secondaryTextStyle(weight: FontWeight.w600),
                        ),
                      ).paddingSymmetric(horizontal: 16),
                      16.height,
                      AppTextField(
                        enabled: !appStore.isLoading,
                        controller: passwordCont,
                        nextFocus: contact,
                        focus: password,
                        textInputAction: TextInputAction.done,
                        textFieldType: TextFieldType.PASSWORD,
                        textStyle: boldTextStyle(),
                        suffixIconColor: appStore.isDarkMode ? bodyDark : bodyWhite,
                        decoration: inputDecoration(
                          context,
                          label: language.password,
                          contentPadding: EdgeInsets.all(0),
                          labelStyle: secondaryTextStyle(weight: FontWeight.w600),
                        ),
                        isPassword: true,
                        onFieldSubmitted: (x) {
                          if (agreeTNC && !appStore.isLoading) {
                            register();
                          } else {
                            toast(language.pleaseAgreeOurTerms);
                          }
                        },
                      ).paddingSymmetric(horizontal: 16),
                      if (appStore.signUpFieldList.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: appStore.signUpFieldList.map((x) {
                            group = x;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(x.groupName.validate(), style: boldTextStyle()).paddingSymmetric(horizontal: 16, vertical: 8),
                                ...x.fields.validate().map((e) {
                                  return ProfileFieldComponent(field: e, count: 0).paddingSymmetric(horizontal: 16, vertical: 8);
                                }).toList(),
                              ],
                            );
                          }).toList(),
                        ).paddingTop(16),
                      Row(
                        children: [
                          Checkbox(
                            shape: RoundedRectangleBorder(borderRadius: radius(2)),
                            activeColor: context.primaryColor,
                            value: agreeTNC,
                            onChanged: (val) {
                              agreeTNC = !agreeTNC;
                              setState(() {});
                            },
                          ),
                          RichTextWidget(
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            list: [
                              TextSpan(text: language.bySigningUpYou + " ", style: secondaryTextStyle(fontFamily: fontFamily)),
                              TextSpan(
                                text: "\n${language.termsCondition}",
                                style: secondaryTextStyle(color: context.primaryColor, decoration: TextDecoration.underline, fontStyle: FontStyle.italic, fontFamily: fontFamily),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    openWebPage(context, url: TERMS_AND_CONDITIONS_URL);
                                  },
                              ),
                              TextSpan(text: " & ", style: secondaryTextStyle()),
                              TextSpan(
                                text: "${language.privacyPolicy}.",
                                style: secondaryTextStyle(color: context.primaryColor, decoration: TextDecoration.underline, fontStyle: FontStyle.italic),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    openWebPage(context, url: PRIVACY_POLICY_URL);
                                  },
                              ),
                            ],
                          ).expand(),
                        ],
                      ).paddingSymmetric(vertical: 16),
                      appButton(
                        context: context,
                        text: language.signUp.capitalizeFirstLetter(),
                        onTap: () {
                          if (agreeTNC && !appStore.isLoading) {
                            register();
                          } else {
                            toast(language.pleaseAgreeOurTerms);
                          }
                        },
                      ),
                      16.height,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(language.alreadyHaveAnAccount, style: secondaryTextStyle()),
                          4.width,
                          Text(
                            language.signIn,
                            style: secondaryTextStyle(color: context.primaryColor, decoration: TextDecoration.underline),
                          ).onTap(() {
                            widget.callback?.call();
                          }, highlightColor: Colors.transparent, splashColor: Colors.transparent)
                        ],
                      ),
                      8.height,
                      if (appStore.isAuthVerificationEnable)
                        InkWell(
                          onTap: () {
                            showVerificationDialog();
                          },
                          highlightColor: Colors.transparent,
                          splashColor: Colors.transparent,
                          child: Text(language.completeTheActivationText, style: secondaryTextStyle(color: context.primaryColor)),
                        ),
                      50.height,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
