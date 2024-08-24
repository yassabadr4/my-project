import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:giphy_get/giphy_get.dart';
import 'package:intl/intl.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:socialv/components/loading_widget.dart';
import 'package:socialv/components/no_data_lottie_widget.dart';
import 'package:socialv/main.dart';
import 'package:socialv/models/common_models/post_mdeia_model.dart';
import 'package:socialv/models/posts/comment_model.dart';
import 'package:socialv/network/rest_apis.dart';
import 'package:socialv/screens/post/components/comment_component.dart';
import 'package:socialv/screens/post/components/update_comment_component.dart';
import 'package:socialv/screens/post/screens/comment_reply_screen.dart';
import 'package:socialv/utils/app_constants.dart';
import 'package:socialv/utils/cached_network_image.dart';

class CommentScreen extends StatefulWidget {
  final int postId;
  final VoidCallback? callback;

  const CommentScreen({required this.postId, this.callback});

  @override
  State<CommentScreen> createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  TextEditingController commentController = TextEditingController();
  FocusNode commentFocus = FocusNode();

  List<CommentModel> commentList = [];
  late Future<List<CommentModel>> future;

  GiphyGif? gif;

  int mPage = 1;
  bool mIsLastPage = false;
  bool isError = false;
  bool isChange = false;
  int commentParentId = -1;

  @override
  void initState() {
    init();
    super.initState();
    afterBuildCreated(() {
      setStatusBarColor(context.cardColor);
    });
  }

  Future<void> init({bool showLoader = true, int page = 1}) async {
    appStore.setLoading(showLoader);
    future = getComments(
      id: widget.postId,
      page: page,
      commentList: commentList,
      lastPageCallback: (p0) {
        setState(() {
          mIsLastPage = p0;
        });
      },
    ).then((value) {
      setState(() {});
      appStore.setLoading(false);
      return value;
    }).catchError((e) {
      isError = true;
      setState(() {});
      appStore.setLoading(false);
      toast(e.toString(), print: true);
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  void deleteComment(int commentId) async {
    ifNotTester(() async {
      appStore.setLoading(true);
      await deletePostComment(postId: widget.postId, commentId: commentId).then((value) {
        init();
        widget.callback?.call();
      }).catchError((e) {
        appStore.setLoading(false);
        toast(e.toString());
      });
    });
  }

  void postComment(String commentContent, {int? parentId}) async {
    ifNotTester(() async {
      var comment = CommentModel(
        content: commentContent,
        userImage: userStore.loginAvatarUrl,
        dateRecorded: DateFormat(DATE_FORMAT_1).format(DateTime.now()),
        userName: userStore.loginFullName,
        medias: gif != null ? [PostMediaModel(url: gif!.images!.original!.url.validate())] : [],
      );

      if (parentId == null) {
        commentList.add(comment);
      } else if (commentList.any((element) => element.id.toInt() == parentId)) {
        var temp = commentList.firstWhere((element) => element.id.toInt() == parentId);

        if (temp.children == null) temp.children = [];
        temp.children!.add(comment);
      } else {
        appStore.setLoading(true);
      }
      Map<String, dynamic> request = {
        "content": commentContent,
        "media_type": gif != null && gif!.images!.original!.url.validate().isNotEmpty ? MediaTypes.gif : "",
        "media_id": gif != null ? gif!.id.validate() : "",
        "media": gif != null ? gif!.images!.original!.url.validate() : "",
      };

      if (parentId != null) request.putIfAbsent('parent_comment_id', () => parentId);

      await savePostComment(postId: widget.postId, request: request).then((value) {
        init();
        widget.callback?.call();
      }).catchError((e) {
        appStore.setLoading(false);
        toast(e.toString());
      });
      gif = null;
      setState(() {});
    });
  }

  Future<void> onRefresh() async {
    init();
  }

  @override
  void dispose() {
    setStatusBarColorBasedOnTheme();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        appStore.setLoading(false);
        finish(context, isChange);
        return Future.value(true);
      },
      child: RefreshIndicator(
        onRefresh: () async {
          onRefresh();
        },
        color: context.primaryColor,
        child: Scaffold(
          backgroundColor: context.cardColor,
          appBar: AppBar(
            backgroundColor: context.cardColor,
            title: Text(language.comments, style: boldTextStyle(size: 20)),
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: context.iconColor),
              onPressed: () {
                finish(context, isChange);
              },
            ),
          ),
          body: SizedBox(
            height: context.height(),
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                FutureBuilder<List<CommentModel>>(
                  future: future,
                  builder: (ctx, snap) {
                    if (snap.hasError) {
                      return NoDataWidget(
                        imageWidget: NoDataLottieWidget(),
                        title: isError ? language.somethingWentWrong : language.noDataFound,
                        onRetry: () {
                          onRefresh();
                        },
                        retryText: '   ${language.clickToRefresh}   ',
                      ).center();
                    }

                    if (snap.hasData) {
                      if (snap.data.validate().isEmpty) {
                        return NoDataWidget(
                          imageWidget: NoDataLottieWidget(),
                          title: isError ? language.somethingWentWrong : language.noDataFound,
                          onRetry: () {
                            onRefresh();
                          },
                          retryText: '   ${language.clickToRefresh}   ',
                        ).center();
                      } else {
                        return AnimatedListView(
                          shrinkWrap: true,
                          slideConfiguration: SlideConfiguration(
                            delay: 80.milliseconds,
                            verticalOffset: 300,
                          ),
                          physics: AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 90),
                          itemCount: commentList.length,
                          itemBuilder: (context, index) {
                            CommentModel _comment = commentList[index];

                            return Column(
                              children: [
                                CommentComponent(
                                  callback: () {
                                    //
                                  },
                                  isParent: true,
                                  comment: _comment,
                                  postId: widget.postId,
                                  onDelete: () {
                                    showConfirmDialogCustom(
                                      context,
                                      dialogType: DialogType.DELETE,
                                      onAccept: (c) {
                                        deleteComment(_comment.id.validate().toInt());
                                      },
                                    );
                                  },
                                  onReply: () async {
                                    FocusScope.of(context).requestFocus(commentFocus);
                                    commentParentId = _comment.id.validate().toInt();
                                  },
                                  onEdit: () {
                                    showInDialog(
                                      context,
                                      contentPadding: EdgeInsets.zero,
                                      builder: (p0) {
                                        return UpdateCommentComponent(
                                          id: _comment.id.validate().toInt(),
                                          activityId: _comment.itemId.validate().toInt(),
                                          comment: _comment.content,
                                          medias: _comment.medias.validate(),
                                          callback: (x) {
                                            init();
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                                if (_comment.children.validate().isNotEmpty)
                                  ListView.separated(
                                    itemBuilder: (context, i) {
                                      CommentModel childComment = _comment.children.validate()[i];

                                      return CommentComponent(
                                        callback: () {
                                          init();
                                        },
                                        isParent: false,
                                        comment: childComment,
                                        postId: widget.postId,
                                        onDelete: () {
                                          deleteComment(childComment.id.toInt());
                                        },
                                        onReply: () async {
                                          CommentReplyScreen(
                                            callback: () {
                                              init();
                                            },
                                            postId: widget.postId,
                                            comment: childComment,
                                          ).launch(context).then((value) {
                                            if (value ?? false) {
                                              init();
                                            }
                                          });
                                        },
                                        onEdit: () {
                                          showInDialog(
                                            context,
                                            contentPadding: EdgeInsets.zero,
                                            builder: (p0) {
                                              return UpdateCommentComponent(
                                                id: childComment.id.validate().toInt(),
                                                activityId: childComment.itemId.validate().toInt(),
                                                comment: childComment.content,
                                                parentId: childComment.secondaryItemId.validate().toInt(),
                                                medias: childComment.medias.validate(),
                                                callback: (x) {
                                                  init();
                                                },
                                              );
                                            },
                                          );
                                        },
                                      );
                                    },
                                    itemCount: _comment.children.validate().length,
                                    physics: NeverScrollableScrollPhysics(),
                                    shrinkWrap: true,
                                    padding: EdgeInsets.only(left: 16, top: 8),
                                    separatorBuilder: (c, i) => Divider(height: 0),
                                  ),
                                Divider(),
                              ],
                            );
                          },
                          onNextPage: () {
                            if (!mIsLastPage) {
                              setState(() {
                                mPage++;
                              });
                              init(page: mPage);
                            }
                          },
                        );
                      }
                    }
                    return Offstage();
                  },
                ),
                Observer(
                  builder: (_) {
                    if (appStore.isLoading) {
                      return Positioned(
                        bottom: mPage != 1 ? 10 : null,
                        child: LoadingWidget(isBlurBackground: mPage == 1 ? true : false),
                      );
                    } else {
                      return Offstage();
                    }
                  },
                ),
                Positioned(
                  bottom: context.navigationBarHeight,
                  child: Container(
                    width: context.width(),
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    color: context.scaffoldBackgroundColor,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            cachedImage(userStore.loginAvatarUrl, height: 36, width: 36, fit: BoxFit.cover).cornerRadiusWithClipRRect(100),
                            10.width,
                            AppTextField(
                              focus: commentFocus,
                              controller: commentController,
                              textFieldType: TextFieldType.MULTILINE,
                              textCapitalization: TextCapitalization.sentences,
                              keyboardType: TextInputType.multiline,
                              minLines: 1,
                              decoration: InputDecoration(
                                hintText: language.writeAComment,
                                hintStyle: secondaryTextStyle(size: 16),
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                              ),
                              onTap: () {
                                /// Clear recently posted comment id
                                commentParentId = -1;
                              },
                            ).expand(),
                            if (appStore.showGif)
                              IconButton(
                                onPressed: () {
                                  selectGif(context: context).then((value) {
                                    if (value != null) {
                                      gif = value;
                                      setState(() {});
                                      log('Gif Url: ${gif!.images!.original!.url.validate()}');
                                    }
                                  });
                                },
                                icon: cachedImage(ic_gif, color: appStore.isDarkMode ? bodyDark : bodyWhite, width: 30, height: 24, fit: BoxFit.contain),
                              ),
                            InkWell(
                              onTap: () {
                                if (commentController.text.isNotEmpty || gif != null) {
                                  hideKeyboard(context);

                                  String content = commentController.text.trim().replaceAll("\n", "</br>").replaceAll(' ', '&nbsp;');
                                  commentController.clear();

                                  setState(() {});
                                  postComment(content, parentId: commentParentId == -1 ? null : commentParentId);
                                } else {
                                  toast(language.writeComment);
                                }
                              },
                              child: cachedImage(ic_send, color: appStore.isDarkMode ? bodyDark : bodyWhite, width: 24, height: 24, fit: BoxFit.cover),
                            ),
                          ],
                        ),
                        if (gif != null)
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              LoadingWidget(isBlurBackground: false).paddingSymmetric(vertical: 16),
                              cachedImage(gif!.images!.original!.url.validate(), height: 200).cornerRadiusWithClipRRect(defaultAppButtonRadius).paddingSymmetric(vertical: 8),
                            ],
                          )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
