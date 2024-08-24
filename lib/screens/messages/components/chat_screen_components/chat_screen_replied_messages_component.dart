import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:socialv/models/messages/message_users.dart';
import 'package:socialv/models/messages/messages_model.dart';
import 'package:socialv/utils/app_constants.dart';
import 'package:socialv/utils/extentions/str_extentions.dart';


class ChatScreenRepliedMessagesComponent extends StatelessWidget {
  final MessagesUsers? repliedUser;
  final Messages? repliedMessage;
  final bool isLoggedInUser;

  const ChatScreenRepliedMessagesComponent({Key? key, this.repliedUser, this.repliedMessage, required this.isLoggedInUser}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (repliedUser != null)
            Text(
              repliedUser!.name.validate(),
              style: boldTextStyle(color: isLoggedInUser ? Colors.white : null, size: 12),
            ),
          if (repliedMessage != null)
            Text(
              repliedMessage!.message.validateAndFilter(),
              style: secondaryTextStyle(color: isLoggedInUser ? Colors.white : null, size: 10),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      decoration: BoxDecoration(
        color: isLoggedInUser ? appGreenColor.withOpacity(0.1) : context.scaffoldBackgroundColor,
        borderRadius: radius(commonRadius),
      ),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}
