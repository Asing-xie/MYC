class AppStrings {
  const AppStrings(this.en);

  final bool en;

  String get appName => 'MWC Chat';
  String get languageToggle => en ? '中文' : 'EN';
  String get messages => en ? 'Messages' : '消息';
  String get contacts => en ? 'Contacts' : '通讯录';
  String get discover => en ? 'Discover' : '发现';
  String get me => en ? 'Me' : '我';
  String get settings => en ? 'Settings' : '设置';
  String get searchUsers => en ? 'Search users' : '搜索用户';
  String get newGroup => en ? 'New group' : '创建群聊';
  String get noConversations => en ? 'No conversations yet' : '暂无会话';
  String get noMessagesYet => en ? 'No messages yet' : '暂无消息';
  String get emailOrPhone => en ? 'Email or phone' : '邮箱或手机号';
  String get password => en ? 'Password' : '密码';
  String get nickname => en ? 'Nickname' : '昵称';
  String get login => en ? 'Login' : '登录';
  String get register => en ? 'Register' : '注册';
  String get createAccount => en ? 'Create account' : '创建账号';
  String get useExistingAccount => en ? 'Use existing account' : '已有账号，去登录';
  String get newFriends => en ? 'New Friends' : '新的朋友';
  String get friendRequests => en ? 'Friend requests' : '好友申请';
  String get noFriendRequests => en ? 'No friend requests' : '暂无好友申请';
  String get reject => en ? 'Reject' : '拒绝';
  String get accept => en ? 'Accept' : '同意';
  String get accepted => en ? 'Accepted' : '已同意';
  String get rejected => en ? 'Rejected' : '已拒绝';
  String get pending => en ? 'Pending' : '待处理';
  String get incomingRequests => en ? 'Incoming requests' : '收到的申请';
  String get outgoingRequests => en ? 'Outgoing requests' : '发出的申请';
  String get clear => en ? 'Clear' : '清空';
  String get search => en ? 'Search' : '搜索';
  String get searchHint =>
      en ? 'Search by email, phone, or nickname' : '通过邮箱、手机号或昵称搜索';
  String get searchFieldLabel => en ? 'Email, phone, or nickname' : '邮箱、手机号或昵称';
  String get noUsersFound => en ? 'No users found' : '没有找到用户';
  String get requestSent => en ? 'Request sent' : '已发送申请';
  String get addFriend => en ? 'Add friend' : '添加好友';
  String get alreadyFriends => en ? 'Already friends' : '已经是好友';
  String get friendRequestSent => en ? 'Friend request sent' : '好友申请已发送';
  String get groupName => en ? 'Group name' : '群名称';
  String get groupSettings => en ? 'Group settings' : '群设置';
  String get groupMembers => en ? 'Group members' : '群成员';
  String get addMembers => en ? 'Add members' : '添加成员';
  String get removeMember => en ? 'Remove member' : '移除成员';
  String get leaveGroup => en ? 'Leave group' : '退出群聊';
  String get dissolveGroup => en ? 'Dissolve group' : '解散群聊';
  String get owner => en ? 'Owner' : '群主';
  String get member => en ? 'Member' : '成员';
  String get noAvailableFriends => en ? 'No available friends' : '没有可添加的好友';
  String get saveGroupName => en ? 'Save group name' : '保存群名称';
  String get leaveGroupConfirm => en ? 'Leave this group?' : '确定退出这个群聊吗？';
  String get dissolveGroupConfirm => en ? 'Dissolve this group?' : '确定解散这个群聊吗？';
  String removeMemberConfirm(String name) =>
      en ? 'Remove $name from the group?' : '将 $name 移出群聊？';
  String get create => en ? 'Create' : '创建';
  String get atLeastTwoFriends =>
      en ? 'At least two friends are required' : '至少需要选择两个好友';
  String selectedCount(int selected, int total) =>
      en ? 'Selected $selected/$total' : '已选择 $selected/$total';
  String get image => en ? 'Image' : '图片';
  String get imagePreview => en ? '[Image]' : '[图片]';
  String get voice => en ? 'Voice' : '语音';
  String get voicePreview => en ? '[Voice]' : '[语音]';
  String get video => en ? 'Video' : '视频';
  String get videoPreview => en ? '[Video]' : '[视频]';
  String get addVideo => en ? 'Add Video' : '添加视频';
  String get cancelVoice => en ? 'Cancel voice' : '取消录音';
  String get sendVoice => en ? 'Send voice' : '发送语音';
  String get stopVoice => en ? 'Stop voice' : '停止录音';
  String get recording => en ? 'Recording...' : '录音中...';
  String get videoTooLong =>
      en ? 'Video must be 15 seconds or shorter' : '视频不能超过15秒';
  String get message => en ? 'Message' : '消息';
  String get send => en ? 'Send' : '发送';
  String get sending => en ? 'Sending...' : '发送中...';
  String get sendFailed => en ? 'Send failed' : '发送失败';
  String get messageSendFailed => en ? 'Message send failed' : '消息发送失败';
  String get micPermissionDenied =>
      en ? 'Microphone permission denied' : '麦克风权限被拒绝';
  String get read => en ? 'Read' : '已读';
  String get delivered => en ? 'Delivered' : '已送达';
  String get imageUnavailable => en ? '[image unavailable]' : '[图片不可用]';
  String voiceMessage(String duration) =>
      en ? 'Voice $duration' : '语音 $duration';
  String videoMessage(String duration) =>
      duration.isEmpty ? video : (en ? 'Video $duration' : '视频 $duration');
  String get profile => en ? 'Profile' : '个人资料';
  String get myProfile => en ? 'My Profile' : '我的资料';
  String get editProfile => en ? 'Edit profile' : '编辑资料';
  String get noSignature => en ? 'No signature' : '暂无签名';
  String get tapAvatarToUpdate => en ? 'Tap avatar to update' : '点击头像更换';
  String get album => en ? 'Album' : '相册';
  String get addPhoto => en ? 'Add Photo' : '添加照片';
  String get noPhotosYet => en ? 'No photos yet' : '暂无照片';
  String get noPublicPhotos => en ? 'No public photos' : '暂无公开照片';
  String get signature => en ? 'Signature' : '签名';
  String get cancel => en ? 'Cancel' : '取消';
  String get save => en ? 'Save' : '保存';
  String get changeLanguage => en ? 'Change language' : '更换系统语言';
  String get loading => en ? 'Loading...' : '加载中...';
  String get logout => en ? 'Logout' : '登出';
  String get logoutConfirm => en ? 'Log out of this account?' : '确定要退出当前账号吗？';
  String get chinese => '中文';
  String get english => 'English';
}
