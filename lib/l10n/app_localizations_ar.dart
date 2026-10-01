// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'سوا';

  @override
  String get appTagline => 'دردش، اتصل، وضلّك قريب.';

  @override
  String get phoneTitle => 'أدخل رقم جوالك';

  @override
  String get phoneSubtitle => 'رح نبعتلك رمز تأكيد برسالة SMS.';

  @override
  String get phoneLabel => 'رقم الجوال';

  @override
  String get phoneInvalid => 'أدخل رقم جوال صحيح';

  @override
  String get sendCode => 'إرسال الرمز';

  @override
  String get otpTitle => 'تأكيد الرقم';

  @override
  String otpSubtitle(String phone) {
    return 'أدخل الرمز المكوّن من 6 أرقام المرسل إلى $phone';
  }

  @override
  String get otpInvalid => 'الرمز غير صحيح أو انتهت صلاحيته';

  @override
  String resendIn(int seconds) {
    return 'إعادة الإرسال بعد $seconds ث';
  }

  @override
  String get resendCode => 'إعادة إرسال الرمز';

  @override
  String get codeResent => 'تم إرسال رمز جديد';

  @override
  String get editNumber => 'الرقم غلط؟';

  @override
  String get verify => 'تأكيد';

  @override
  String get setupTitle => 'جهّز ملفك الشخصي';

  @override
  String setupStep(int current, int total) {
    return 'الخطوة $current من $total';
  }

  @override
  String get setupStep1Subtitle => 'أضف صورة والاسم اللي رح يشوفه أصحابك.';

  @override
  String get setupStep2Subtitle => 'اختر اسم مستخدم فريد عشان الناس تلاقيك.';

  @override
  String get displayName => 'الاسم';

  @override
  String get displayNameRequired => 'أدخل اسمك';

  @override
  String get username => 'اسم المستخدم';

  @override
  String get usernameHelper => 'من 3 إلى 20 حرف: a–z و 0–9 و _';

  @override
  String get usernameInvalid => 'استخدم من 3 إلى 20 حرف: a–z و 0–9 و _';

  @override
  String get usernameTaken => 'اسم المستخدم محجوز';

  @override
  String get usernameAvailable => 'متاح';

  @override
  String get bio => 'نبذة';

  @override
  String get bioHint => 'إشي عنك (اختياري)';

  @override
  String get next => 'التالي';

  @override
  String get back => 'رجوع';

  @override
  String get finish => 'يلا نبدأ';

  @override
  String get addPhoto => 'إضافة صورة';

  @override
  String get pickFromGallery => 'اختيار من المعرض';

  @override
  String get takePhoto => 'التقاط صورة';

  @override
  String get removePhoto => 'إزالة الصورة';

  @override
  String get chats => 'المحادثات';

  @override
  String get calls => 'المكالمات';

  @override
  String get settings => 'الإعدادات';

  @override
  String get noChatsTitle => 'ما في محادثات لسا';

  @override
  String get noChatsBody => 'دوّر على أصحابك بالاسم أو اسم المستخدم أو رقم الجوال وابدأ الدردشة.';

  @override
  String get noCallsTitle => 'ما في مكالمات لسا';

  @override
  String get noCallsBody => 'مكالماتك الصوتية والمرئية رح تظهر هون.';

  @override
  String get newChat => 'محادثة جديدة';

  @override
  String get comingSoon => 'قريبًا';

  @override
  String get appearance => 'المظهر';

  @override
  String get language => 'اللغة';

  @override
  String get languageSystem => 'حسب الجهاز';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'English';

  @override
  String get theme => 'الثيم';

  @override
  String get themeSystem => 'حسب الجهاز';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get account => 'الحساب';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get signOutConfirm => 'بدك تسجّل خروج من سوا؟';

  @override
  String get cancel => 'إلغاء';

  @override
  String get retry => 'حاول مرة تانية';

  @override
  String get searchHint => 'الاسم أو @اسم_المستخدم أو رقم الجوال';

  @override
  String get searchPrompt => 'لاقي أصحابك على سوا';

  @override
  String get searchPromptBody => 'اكتب حرفين على الأقل عشان تدوّر.';

  @override
  String get searchNoResults => 'ما لقينا حدا';

  @override
  String get today => 'اليوم';

  @override
  String get yesterday => 'أمس';

  @override
  String get you => 'أنت';

  @override
  String get typeMessage => 'اكتب رسالة';

  @override
  String get send => 'إرسال';

  @override
  String get attachPhoto => 'إرسال صور';

  @override
  String get recordVoice => 'تسجيل رسالة صوتية';

  @override
  String get holdToRecord => 'اضغط مطوّلًا للتسجيل، واترك للإرسال';

  @override
  String get slideToCancel => 'اسحب للإلغاء';

  @override
  String get micPermission => 'اسمح بالوصول للمايكروفون عشان تبعت رسائل صوتية';

  @override
  String get play => 'تشغيل';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get playbackSpeed => 'سرعة التشغيل';

  @override
  String get sayHi => 'ما في رسائل لسا. قول مرحبا 👋';

  @override
  String get notSentTapToRetry => 'ما انبعتت · اضغط لإعادة المحاولة';

  @override
  String get photo => 'صورة';

  @override
  String get voiceMessage => 'رسالة صوتية';

  @override
  String get messageDeleted => 'تم حذف هذه الرسالة';

  @override
  String get loadFailed => 'ما قدرنا نحمّل الرسائل';

  @override
  String get online => 'متصل الآن';

  @override
  String get typing => 'يكتب…';

  @override
  String lastSeenToday(String time) {
    return 'آخر ظهور اليوم $time';
  }

  @override
  String lastSeenYesterday(String time) {
    return 'آخر ظهور أمس $time';
  }

  @override
  String lastSeenOn(String date) {
    return 'آخر ظهور $date';
  }

  @override
  String unreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة غير مقروءة',
      few: '$count رسائل غير مقروءة',
      two: 'رسالتان غير مقروءتين',
      one: 'رسالة غير مقروءة',
    );
    return '$_temp0';
  }

  @override
  String get errorGeneric => 'صار خطأ، جرّب مرة تانية.';

  @override
  String get errorNetwork => 'ما في اتصال بالإنترنت';

  @override
  String get errorTooManyRequests => 'محاولات كتير، استنى شوي وجرّب مرة تانية.';

  @override
  String get newGroup => 'مجموعة جديدة';

  @override
  String get addMembers => 'إضافة أعضاء';

  @override
  String selectedCount(int count) {
    return '$count محدد';
  }

  @override
  String get groupName => 'اسم المجموعة';

  @override
  String get groupNameRequired => 'أدخل اسم المجموعة';

  @override
  String get groupDescription => 'الوصف (اختياري)';

  @override
  String get create => 'إنشاء';

  @override
  String get selectAtLeastOne => 'اختر شخص واحد على الأقل';

  @override
  String get peopleYouChatWith => 'اللي بتحكي معهم';

  @override
  String get members => 'الأعضاء';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عضو',
      few: '$count أعضاء',
      two: 'عضوان',
      one: 'عضو واحد',
    );
    return '$_temp0';
  }

  @override
  String get groupInfo => 'معلومات المجموعة';

  @override
  String get admin => 'مشرف';

  @override
  String get owner => 'المالك';

  @override
  String get makeAdmin => 'تعيين كمشرف';

  @override
  String get dismissAdmin => 'إلغاء الإشراف';

  @override
  String get removeFromGroup => 'إزالة من المجموعة';

  @override
  String get leaveGroup => 'مغادرة المجموعة';

  @override
  String leaveGroupConfirm(String name) {
    return 'بدك تغادر \"$name\"؟ ما رح توصلك رسائلها بعد هيك.';
  }

  @override
  String get editGroup => 'تعديل المجموعة';

  @override
  String get save => 'حفظ';

  @override
  String get sendMessage => 'مراسلة';

  @override
  String get someone => 'شخص ما';

  @override
  String get notAMember => 'ما بتقدر تبعت رسائل لهالمجموعة لأنك ما عدت عضو فيها';

  @override
  String evCreated(String actor, String name) {
    return '$actor أنشأ المجموعة \"$name\"';
  }

  @override
  String evCreatedYou(String name) {
    return 'أنشأتَ المجموعة \"$name\"';
  }

  @override
  String evAdded(String actor, String targets) {
    return '$actor أضاف $targets';
  }

  @override
  String evAddedYou(String targets) {
    return 'أضفتَ $targets';
  }

  @override
  String evAddedMe(String actor) {
    return '$actor أضافك';
  }

  @override
  String evRemoved(String actor, String targets) {
    return '$actor أزال $targets';
  }

  @override
  String evRemovedYou(String targets) {
    return 'أزلتَ $targets';
  }

  @override
  String evRemovedMe(String actor) {
    return '$actor أزالك';
  }

  @override
  String evLeft(String actor) {
    return '$actor غادر المجموعة';
  }

  @override
  String get evLeftYou => 'غادرتَ المجموعة';

  @override
  String evRenamed(String actor, String name) {
    return '$actor غيّر اسم المجموعة إلى \"$name\"';
  }

  @override
  String evRenamedYou(String name) {
    return 'غيّرتَ اسم المجموعة إلى \"$name\"';
  }

  @override
  String evPhoto(String actor) {
    return '$actor غيّر صورة المجموعة';
  }

  @override
  String get evPhotoYou => 'غيّرتَ صورة المجموعة';

  @override
  String evPromoted(String actor, String targets) {
    return '$actor عيّن $targets مشرفًا';
  }

  @override
  String evPromotedYou(String targets) {
    return 'عيّنتَ $targets مشرفًا';
  }

  @override
  String evPromotedMe(String actor) {
    return '$actor عيّنك مشرفًا';
  }

  @override
  String evDemoted(String actor, String targets) {
    return '$actor ألغى إشراف $targets';
  }

  @override
  String evDemotedYou(String targets) {
    return 'ألغيتَ إشراف $targets';
  }

  @override
  String evDemotedMe(String actor) {
    return '$actor ألغى إشرافك';
  }

  @override
  String get audioCall => 'مكالمة صوتية';

  @override
  String get videoCall => 'مكالمة فيديو';

  @override
  String get calling => 'جاري الاتصال…';

  @override
  String get incomingAudioCall => 'مكالمة صوتية واردة';

  @override
  String get incomingVideoCall => 'مكالمة فيديو واردة';

  @override
  String get connecting => 'جاري الربط…';

  @override
  String get callEnded => 'انتهت المكالمة';

  @override
  String get callDeclined => 'مرفوضة';

  @override
  String get callBusy => 'مشغول';

  @override
  String get callNoAnswer => 'ما في رد';

  @override
  String get callFailed => 'فشلت المكالمة';

  @override
  String get accept => 'رد';

  @override
  String get decline => 'رفض';

  @override
  String get mute => 'كتم';

  @override
  String get speaker => 'السماعة';

  @override
  String get cameraLabel => 'الكاميرا';

  @override
  String get flipCamera => 'تبديل';

  @override
  String get endCall => 'إنهاء';

  @override
  String get missedCall => 'مكالمة فائتة';

  @override
  String get outgoingCall => 'مكالمة صادرة';

  @override
  String get incomingCall => 'مكالمة واردة';

  @override
  String get blockUser => 'حظر';

  @override
  String get unblockUser => 'إلغاء الحظر';

  @override
  String blockConfirm(String name) {
    return 'بدك تحظر $name؟ ما رح يقدر يراسلك أو يتصل فيك.';
  }

  @override
  String get youBlockedThem => 'إنت حاظر هالشخص';

  @override
  String get blockedUsers => 'المحظورين';

  @override
  String get noBlockedUsers => 'ما في حدا محظور';
}
