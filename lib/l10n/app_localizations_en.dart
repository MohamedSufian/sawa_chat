// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Sawa';

  @override
  String get appTagline => 'Chat, call, and stay close.';

  @override
  String get phoneTitle => 'Enter your phone number';

  @override
  String get phoneSubtitle => 'We\'ll send you a verification code by SMS.';

  @override
  String get phoneLabel => 'Phone number';

  @override
  String get phoneInvalid => 'Enter a valid mobile number';

  @override
  String get sendCode => 'Send code';

  @override
  String get otpTitle => 'Verify your number';

  @override
  String otpSubtitle(String phone) {
    return 'Enter the 6-digit code sent to $phone';
  }

  @override
  String get otpInvalid => 'The code is wrong or has expired';

  @override
  String resendIn(int seconds) {
    return 'Resend code in ${seconds}s';
  }

  @override
  String get resendCode => 'Resend code';

  @override
  String get codeResent => 'A new code was sent';

  @override
  String get editNumber => 'Wrong number?';

  @override
  String get verify => 'Verify';

  @override
  String get setupTitle => 'Set up your profile';

  @override
  String setupStep(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get setupStep1Subtitle => 'Add a photo and the name your friends will see.';

  @override
  String get setupStep2Subtitle => 'Pick a unique username so people can find you.';

  @override
  String get displayName => 'Name';

  @override
  String get displayNameRequired => 'Enter your name';

  @override
  String get username => 'Username';

  @override
  String get usernameHelper => '3–20 characters: a–z, 0–9 and _';

  @override
  String get usernameInvalid => 'Use 3–20 characters: a–z, 0–9 and _';

  @override
  String get usernameTaken => 'This username is taken';

  @override
  String get usernameAvailable => 'Available';

  @override
  String get bio => 'Bio';

  @override
  String get bioHint => 'Something about you (optional)';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get finish => 'Start chatting';

  @override
  String get addPhoto => 'Add photo';

  @override
  String get pickFromGallery => 'Choose from gallery';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get chats => 'Chats';

  @override
  String get calls => 'Calls';

  @override
  String get settings => 'Settings';

  @override
  String get noChatsTitle => 'No chats yet';

  @override
  String get noChatsBody => 'Search for friends by name, username or phone number to start chatting.';

  @override
  String get noCallsTitle => 'No calls yet';

  @override
  String get noCallsBody => 'Your voice and video calls will show up here.';

  @override
  String get newChat => 'New chat';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get appearance => 'Appearance';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'English';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System default';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get account => 'Account';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutConfirm => 'Do you want to sign out of Sawa?';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Try again';

  @override
  String get searchHint => 'Name, @username or phone number';

  @override
  String get searchPrompt => 'Find friends on Sawa';

  @override
  String get searchPromptBody => 'Type at least 2 characters to search.';

  @override
  String get searchNoResults => 'No users found';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get you => 'You';

  @override
  String get typeMessage => 'Message';

  @override
  String get send => 'Send';

  @override
  String get attachPhoto => 'Send photos';

  @override
  String get recordVoice => 'Record voice message';

  @override
  String get holdToRecord => 'Hold to record, release to send';

  @override
  String get slideToCancel => 'Slide to cancel';

  @override
  String get micPermission => 'Allow microphone access to send voice messages';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get playbackSpeed => 'Playback speed';

  @override
  String get sayHi => 'No messages yet. Say hi 👋';

  @override
  String get notSentTapToRetry => 'Not sent · Tap to retry';

  @override
  String get photo => 'Photo';

  @override
  String get voiceMessage => 'Voice message';

  @override
  String get messageDeleted => 'This message was deleted';

  @override
  String get loadFailed => 'Couldn\'t load messages';

  @override
  String get online => 'online';

  @override
  String get typing => 'typing…';

  @override
  String lastSeenToday(String time) {
    return 'last seen today at $time';
  }

  @override
  String lastSeenYesterday(String time) {
    return 'last seen yesterday at $time';
  }

  @override
  String lastSeenOn(String date) {
    return 'last seen $date';
  }

  @override
  String unreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread messages',
      one: '1 unread message',
    );
    return '$_temp0';
  }

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorNetwork => 'No internet connection';

  @override
  String get errorTooManyRequests => 'Too many attempts. Please wait a moment and try again.';

  @override
  String get newGroup => 'New group';

  @override
  String get addMembers => 'Add members';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get groupName => 'Group name';

  @override
  String get groupNameRequired => 'Enter a group name';

  @override
  String get groupDescription => 'Description (optional)';

  @override
  String get create => 'Create';

  @override
  String get selectAtLeastOne => 'Pick at least one person';

  @override
  String get peopleYouChatWith => 'People you chat with';

  @override
  String get members => 'Members';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count members', one: '1 member');
    return '$_temp0';
  }

  @override
  String get groupInfo => 'Group info';

  @override
  String get admin => 'Admin';

  @override
  String get owner => 'Owner';

  @override
  String get makeAdmin => 'Make admin';

  @override
  String get dismissAdmin => 'Dismiss as admin';

  @override
  String get removeFromGroup => 'Remove from group';

  @override
  String get leaveGroup => 'Leave group';

  @override
  String leaveGroupConfirm(String name) {
    return 'Leave \"$name\"? You won\'t get its messages anymore.';
  }

  @override
  String get editGroup => 'Edit group';

  @override
  String get save => 'Save';

  @override
  String get sendMessage => 'Message';

  @override
  String get someone => 'Someone';

  @override
  String get notAMember => 'You can\'t send messages to this group because you\'re no longer a member';

  @override
  String evCreated(String actor, String name) {
    return '$actor created the group \"$name\"';
  }

  @override
  String evCreatedYou(String name) {
    return 'You created the group \"$name\"';
  }

  @override
  String evAdded(String actor, String targets) {
    return '$actor added $targets';
  }

  @override
  String evAddedYou(String targets) {
    return 'You added $targets';
  }

  @override
  String evAddedMe(String actor) {
    return '$actor added you';
  }

  @override
  String evRemoved(String actor, String targets) {
    return '$actor removed $targets';
  }

  @override
  String evRemovedYou(String targets) {
    return 'You removed $targets';
  }

  @override
  String evRemovedMe(String actor) {
    return '$actor removed you';
  }

  @override
  String evLeft(String actor) {
    return '$actor left';
  }

  @override
  String get evLeftYou => 'You left';

  @override
  String evRenamed(String actor, String name) {
    return '$actor changed the group name to \"$name\"';
  }

  @override
  String evRenamedYou(String name) {
    return 'You changed the group name to \"$name\"';
  }

  @override
  String evPhoto(String actor) {
    return '$actor changed the group photo';
  }

  @override
  String get evPhotoYou => 'You changed the group photo';

  @override
  String evPromoted(String actor, String targets) {
    return '$actor made $targets an admin';
  }

  @override
  String evPromotedYou(String targets) {
    return 'You made $targets an admin';
  }

  @override
  String evPromotedMe(String actor) {
    return '$actor made you an admin';
  }

  @override
  String evDemoted(String actor, String targets) {
    return '$actor dismissed $targets as admin';
  }

  @override
  String evDemotedYou(String targets) {
    return 'You dismissed $targets as admin';
  }

  @override
  String evDemotedMe(String actor) {
    return '$actor dismissed you as admin';
  }

  @override
  String get audioCall => 'Voice call';

  @override
  String get videoCall => 'Video call';

  @override
  String get calling => 'Calling…';

  @override
  String get incomingAudioCall => 'Incoming voice call';

  @override
  String get incomingVideoCall => 'Incoming video call';

  @override
  String get connecting => 'Connecting…';

  @override
  String get callEnded => 'Call ended';

  @override
  String get callDeclined => 'Declined';

  @override
  String get callBusy => 'Busy';

  @override
  String get callNoAnswer => 'No answer';

  @override
  String get callFailed => 'Call failed';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get mute => 'Mute';

  @override
  String get speaker => 'Speaker';

  @override
  String get cameraLabel => 'Camera';

  @override
  String get flipCamera => 'Flip';

  @override
  String get endCall => 'End';

  @override
  String get missedCall => 'Missed call';

  @override
  String get outgoingCall => 'Outgoing call';

  @override
  String get incomingCall => 'Incoming call';

  @override
  String get blockUser => 'Block';

  @override
  String get unblockUser => 'Unblock';

  @override
  String blockConfirm(String name) {
    return 'Block $name? They won\'t be able to message or call you.';
  }

  @override
  String get youBlockedThem => 'You blocked this contact';

  @override
  String get blockedUsers => 'Blocked users';

  @override
  String get noBlockedUsers => 'No blocked users';
}
