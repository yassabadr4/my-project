import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:socialv/main.dart';
import 'package:socialv/screens/messages/screens/chat_screen.dart';
import 'package:socialv/utils/app_constants.dart';

import '../screens/groups/screens/group_detail_screen.dart';
import '../screens/membership/screens/membership_plans_screen.dart';
import '../screens/post/screens/comment_screen.dart';
import '../screens/post/screens/single_post_screen.dart';
import '../screens/profile/screens/member_profile_screen.dart';

class PushNotificationService {
  Future<void> initFirebaseMessaging() async {
    await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, provisional: false, sound: true).then((value) {
      if (value.authorizationStatus == AuthorizationStatus.authorized) {
        registerNotificationListeners();

        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

        FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
      }
    });
  }

  Future<void> subscribeToFirebaseTopic() async {
    if (appStore.isLoggedIn) {
      if (Platform.isIOS) {
        String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();

        if (apnsToken != null) {
          await FirebaseMessaging.instance.subscribeToTopic('user_${userStore.loginUserId}').then((value) {
            log("${FirebaseMsgConst.topicSubscribed} user_${userStore.loginUserId}");
          });
        } else {
          await Future<void>.delayed(const Duration(seconds: 3));
          apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          if (apnsToken != null) {
            await FirebaseMessaging.instance.subscribeToTopic('user_${userStore.loginUserId}').then((value) {
              log("${FirebaseMsgConst.topicSubscribed} user_${userStore.loginUserId}");
            });
          }
        }
      } else {
        await FirebaseMessaging.instance.subscribeToTopic('user_${userStore.loginUserId}').then((value) {
          log("${FirebaseMsgConst.topicSubscribed} user_${userStore.loginUserId}");
        });
      }
      FirebaseMessaging.instance.getToken().then((v) {
        setValue(SharePreferencesKey.firebaseToken, v, print: true);
      });
    }
  }

  void handleNotificationClick(RemoteMessage message, {bool isForeGround = false}) {
    printLogsNotificationData(message);

    if (isForeGround) {
      showNotification(currentTimeStamp(), message.notification!.title.validate(), message.notification!.body.validate(), message);
    } else {
      try {
        log('Additional Data------RunTime Type - ${jsonDecode(message.data[FirebaseMsgConst.additionalDataKey]).runtimeType}--------------------${jsonDecode(message.data[FirebaseMsgConst.additionalDataKey])}');

        Map<String, dynamic> additionalData = jsonDecode(message.data[FirebaseMsgConst.additionalDataKey]) ?? {};

        if (additionalData.isNotEmpty) {
          additionalData.entries.forEach((element) {
            log('-------------------->>${element.key}');
            if (element.key == FirebaseMsgConst.isCommentKey) {
              int postId = additionalData.entries.firstWhere((element) => element.key == FirebaseMsgConst.postIdKey).value;
              if (postId != 0) {
                navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => CommentScreen(postId: postId)));
              }
            } else if (element.key == FirebaseMsgConst.postIdKey) {
              if (element.value.toString().toInt() != 0) {
                //Todo verify This Screen
                navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => SinglePostScreen(postId: element.value.toString().toInt())));
              }
            } else if (element.key == FirebaseMsgConst.userIdKey) {
              navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => MemberProfileScreen(memberId: element.value)));
            } else if (element.key == FirebaseMsgConst.groupIdKey) {
              if (pmpStore.viewSingleGroup) {
                navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => GroupDetailScreen(groupId: element.value)));
              } else {
                navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => MembershipPlansScreen()));
              }
            } else if (element.key == FirebaseMsgConst.threadId) {
              if (pmpStore.privateMessaging) {
                navigatorKey.currentState!.push(
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      threadId: element.value,
                      onDeleteThread: () {
                        finish(context);
                      },
                    ),
                  ),
                );
              } else {
                navigatorKey.currentState!.push(MaterialPageRoute(builder: (context) => MembershipPlansScreen()));
              }
            }
          });
        }
      } catch (e) {
        log("${FirebaseMsgConst.onClickListener} $e");
      }
    }
  }

  Future<void> registerNotificationListeners() async {
    FirebaseMessaging.instance.setAutoInitEnabled(true).then((value) {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        handleNotificationClick(message, isForeGround: true);
      }, onError: (e) {
        log("${FirebaseMsgConst.onMessageListen} $e");
      });

      // replacement for onResume: When the app is in the background and opened directly from the push notification.
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        handleNotificationClick(message);
      }, onError: (e) {
        log("${FirebaseMsgConst.onMessageOpened} $e");
      });

      // workaround for onLaunch: When the app is completely closed (not in the background) and opened directly from the push notification
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          handleNotificationClick(message);
        }
      }, onError: (e) {
        log("${FirebaseMsgConst.onGetInitialMessage} $e");
      });
    }).onError((error, stackTrace) {
      log("${FirebaseMsgConst.onGetInitialMessage} $error");
    });
  }

  Future<void> showNotification(int id, String title, String message, RemoteMessage remoteMessage) async {
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    //code for background notification channel
    AndroidNotificationChannel channel = AndroidNotificationChannel(
      'notification',
      'Notification',
      importance: Importance.high,
      enableLights: true,
      playSound: true,
      showBadge: true,
      enableVibration: true, ledColor: appColorPrimary);

    await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@drawable/ic_stat_ic_notification');

    var iOS = DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
      onDidReceiveLocalNotification: (id, title, body, payload) {
        handleNotificationClick(remoteMessage);
      },
    );
    var macOS = iOS;
    final InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid, iOS: iOS, macOS: macOS);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        handleNotificationClick(remoteMessage);
      },
    );

    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
      FirebaseMsgConst.notificationChannelIdKey,
      FirebaseMsgConst.notificationChannelNameKey,
      importance: Importance.high,
      visibility: NotificationVisibility.public,
      autoCancel: true,
      playSound: true,
      priority: Priority.high,
      channelShowBadge: true,
      colorized: true,
      color: appColorPrimary,
      icon: '@drawable/ic_stat_ic_notification',
    );

    var darwinPlatformChannelSpecifics = const DarwinNotificationDetails();

    var platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
      macOS: darwinPlatformChannelSpecifics,
    );

    flutterLocalNotificationsPlugin.show(id, title, message, platformChannelSpecifics);
  }

  void printLogsNotificationData(RemoteMessage message) {
    log('${FirebaseMsgConst.notificationDataKey} : ${message.data}');
    log('${FirebaseMsgConst.notificationTitleKey} : ${message.notification!.title}');
    log('${FirebaseMsgConst.notificationBodyKey} : ${message.notification!.body}');
    log('${FirebaseMsgConst.messageDataCollapseKey} : ${message.collapseKey}');
    log('${FirebaseMsgConst.messageDataMessageIdKey} : ${message.messageId}');
    log('${FirebaseMsgConst.messageDataMessageTypeKey} : ${message.messageType}');
  }
}
