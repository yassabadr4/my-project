import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:socialv/main.dart';
import 'package:socialv/models/calls/user_model.dart';
import 'package:socialv/screens/messages/screens/message_screen.dart';
import 'package:socialv/screens/messages/screens/set_chat_wallpaper_screen.dart';
import 'package:socialv/utils/app_constants.dart';
import 'package:socialv/utils/cached_network_image.dart';
import 'package:socialv/utils/call/call_functions.dart';

import '../../../../models/messages/message_users.dart';
import '../../../../models/messages/threads_model.dart';
import '../../../../network/messages_repository.dart';
import '../../../../utils/call/permissions.dart';
import '../../screens/participants_screen.dart';
import '../add_new_participant_component.dart';

enum ChatScreenPopUpMenuComponentCallbacks { MuteOrUnMute, GetThread, SetState, DeleteThread }

// ignore: must_be_immutable
class ChatScreenPopUpMenuComponent extends StatefulWidget {
  final Threads? thread;
  final int? threadId;
  final MessagesUsers? user;
  List<MessagesUsers>? users = [];
  final Function(ChatScreenPopUpMenuComponentCallbacks)? callback;
  final Function(File?)? sendFile;
  final String? wallpaper;

  bool? doRefresh;

  ChatScreenPopUpMenuComponent({this.users, required this.thread, this.threadId, this.user, this.doRefresh, this.callback, this.sendFile, this.wallpaper});

  @override
  State<ChatScreenPopUpMenuComponent> createState() => _ChatScreenPopUpMenuComponentState();
}

class _ChatScreenPopUpMenuComponentState extends State<ChatScreenPopUpMenuComponent> {
  Future<void> onStartCall({required String callType}) async {
    appStore.setLoading(true);

    if (appStore.isWebsocketEnable) {
      String message =
          '42["${SocketEvents.mediaEvent}",{"event":"${SocketEvents.calling}","to":${widget.user!.userId.validate()},"thread_id":${widget.threadId},"type":"$callType","avatar":"${userStore.loginAvatarUrl}","name":"${userStore.loginFullName}"}]';

      log('Send Message: $message');

      channel?.sink.add(message);
    }

    Map request = {"user_id": widget.user!.userId.validate(), "thread_id": widget.threadId, "type": "$callType"};
    await startCall(request: request).then((value) async {
      if (await Permissions.cameraAndMicrophonePermissionsGranted()) {
        UserModel sender = UserModel(
          name: userStore.loginFullName,
          photoUrl: userStore.loginAvatarUrl,
          uid: userStore.loginUserId,
        );

        UserModel receiverUser = UserModel(
          name: widget.user!.name.validate(),
          photoUrl: widget.user!.avatar.validate(),
          uid: widget.user!.userId.validate().toString(),
          oneSignalPlayerId: [],
        );

        CallFunctions.dial(
          context: context,
          from: sender,
          to: receiverUser,
          messageId: value.messageId.validate(),
          threadId: widget.threadId.validate(),
          callType: callType,
        );
      } else {
        toast('You Cannot Start');
      }
    }).catchError((e) {
      log('Error ------------ ${e.toString()}');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.thread != null) {
      return Row(
        children: [
          if (widget.thread!.permissions!.canAudioCall.validate() && widget.thread!.participantsCount.validate() <= 2)
            InkWell(
              onTap: () {
                onStartCall(callType: BetterMessageCallType.audio);
              },
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: cachedImage(ic_call, height: 20, width: 20, color: context.iconColor),
            ).paddingSymmetric(horizontal: 6),
          if (widget.thread!.permissions!.canVideoCall.validate() && widget.thread!.participantsCount.validate() <= 2)
            InkWell(
              onTap: () {
                onStartCall(callType: BetterMessageCallType.video);
              },
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: cachedImage(ic_video_call, height: 20, width: 20, color: context.iconColor),
            ).paddingSymmetric(horizontal: 6),
          Theme(
            data: Theme.of(context).copyWith(),
            child: PopupMenuButton(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(commonRadius)),
              onSelected: (val) async {
                if (val == 1) {
                  ParticipantsScreen(
                    canInvite: widget.thread!.meta!.allowInvite,
                    isModerator: widget.thread!.permissions!.isModerator,
                    participantsCount: widget.thread!.participantsCount.validate(),
                    threadId: widget.threadId.validate(),
                    user: widget.users.validate(),
                  ).launch(context);
                } else if (val == 2) {
                  if (widget.user!.blocked == 0) {
                    widget.user!.blocked = 1;
                    blockUser(userId: widget.user!.userId.validate()).then((value) {
                      widget.callback?.call(ChatScreenPopUpMenuComponentCallbacks.GetThread);
                    });
                  } else {
                    widget.user!.blocked = 0;
                    appStore.setLoading(true);
                    unblockUser(userId: widget.user!.userId.validate()).then((value) {
                      appStore.setLoading(false);
                      widget.callback?.call(ChatScreenPopUpMenuComponentCallbacks.GetThread);
                    });
                  }
                  widget.callback?.call(ChatScreenPopUpMenuComponentCallbacks.SetState);
                } else if (val == 3) {
                  if (widget.thread!.permissions!.isMuted.validate()) {
                    appStore.setLoading(true);
                    await unMuteThread(threadId: widget.threadId.validate()).then((value) {
                      appStore.setLoading(false);
                      widget.callback?.call(ChatScreenPopUpMenuComponentCallbacks.MuteOrUnMute);
                    }).catchError(onError);
                  } else {
                    await muteThread(threadId: widget.threadId.validate()).then((value) {
                      widget.callback?.call(ChatScreenPopUpMenuComponentCallbacks.MuteOrUnMute);
                    }).catchError(onError);
                  }
                  widget.thread!.permissions!.isMuted = !widget.thread!.permissions!.isMuted.validate();
                  widget.callback?.call(ChatScreenPopUpMenuComponentCallbacks.SetState);
                } else if (val == 4) {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    isDismissible: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) {
                      return FractionallySizedBox(
                        heightFactor: 0.8,
                        child: AddNewParticipantComponent(
                          threadId: widget.threadId.validate(),
                          callback: () {
                            finish(context);
                            widget.callback?.call(ChatScreenPopUpMenuComponentCallbacks.GetThread);
                          },
                        ),
                      );
                    },
                  );
                } else if (val == 5) {
                  ParticipantsScreen(
                    canInvite: widget.thread!.meta!.allowInvite,
                    isModerator: widget.thread!.permissions!.isModerator,
                    participantsCount: widget.thread!.participantsCount.validate(),
                    threadId: widget.threadId.validate(),
                    user: widget.users.validate(),
                  ).launch(context).then((value) {
                    if (value ?? false) {
                      widget.callback?.call(ChatScreenPopUpMenuComponentCallbacks.GetThread);
                      widget.doRefresh = true;
                    }
                  });
                } else if (val == 6) {
                  showConfirmDialogCustom(
                    context,
                    onAccept: (c) {
                      ifNotTester(() async {
                        await deleteThread(threadId: widget.threadId.validate().validate()).then((value) {
                          widget.callback?.call(ChatScreenPopUpMenuComponentCallbacks.DeleteThread);
                        }).catchError(onError);
                      });
                    },
                    dialogType: DialogType.CONFIRMATION,
                    title: language.deleteChatConfirmation,
                    positiveText: language.delete,
                  );
                } else if (val == 7) {
                  await leaveFromParticipants(threadId: widget.threadId.validate()).then((value) {
                    finish(context, true);
                  }).catchError(onError);
                } else if (val == 8) {
                  SetChatWallpaperScreen(
                    isGeneralSetting: false,
                    threadId: widget.threadId.validate(),
                    sendFile: (file) {
                      widget.sendFile?.call(file ?? null);
                    },
                    wallpaperUrl: widget.wallpaper,
                  ).launch(context);
                }
              },
              icon: Icon(Icons.more_horiz, color: context.iconColor),
              itemBuilder: (context) => <PopupMenuEntry>[
                if (widget.thread!.type == ThreadType.group)
                  PopupMenuItem(
                    value: 1,
                    child: TextIcon(
                      text: language.viewParticipants,
                      textStyle: secondaryTextStyle(),
                    ),
                  ),
                if (messageStore.allowBlock && widget.thread!.type == ThreadType.thread && widget.thread!.participantsCount.validate() == 2)
                  PopupMenuItem(
                    value: 2,
                    child: TextIcon(
                      text: widget.user!.blocked.validate() == 0 ? language.block : language.unblock,
                      textStyle: secondaryTextStyle(),
                    ),
                  ),
                if (widget.thread!.permissions!.canMuteThread.validate())
                  PopupMenuItem(
                    value: 3,
                    child: TextIcon(
                      text: widget.thread!.permissions!.isMuted.validate() ? language.unMuteConversation : language.muteConversation,
                      textStyle: secondaryTextStyle(),
                    ),
                  ),
                if (widget.thread!.participantsCount.validate() == 2 || widget.thread!.permissions!.isModerator.validate() || widget.thread!.meta!.allowInvite.validate())
                  PopupMenuItem(
                    value: 4,
                    child: TextIcon(
                      text: language.addNewParticipant,
                      textStyle: secondaryTextStyle(),
                    ),
                  ),
                if (widget.thread!.participantsCount.validate() > 2 && widget.thread!.type != ThreadType.group)
                  PopupMenuItem(
                    value: 5,
                    child: TextIcon(
                      text: language.viewParticipants,
                      textStyle: secondaryTextStyle(),
                    ),
                  ),
                if (widget.thread!.permissions!.deleteAllowed.validate())
                  PopupMenuItem(
                    value: 6,
                    child: TextIcon(
                      text: language.deleteConversation,
                      textStyle: secondaryTextStyle(),
                    ),
                  ),
                if (widget.thread!.participantsCount.validate() > 2 && widget.thread!.type != ThreadType.group && !widget.thread!.permissions!.isModerator.validate())
                  PopupMenuItem(
                    value: 7,
                    child: TextIcon(
                      text: language.leave,
                      textStyle: secondaryTextStyle(),
                    ),
                  ),
                PopupMenuItem(
                  value: 8,
                  child: TextIcon(
                    text: language.wallpaper,
                    textStyle: secondaryTextStyle(),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      return Offstage();
    }
  }
}
