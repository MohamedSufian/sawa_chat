abstract final class Routes {
  static const splash = '/splash';
  static const phone = '/auth/phone';
  static const otp = '/auth/otp';
  static const setup = '/setup';
  static const chats = '/chats';
  static const calls = '/calls';
  static const settings = '/settings';
  static const search = '/search';
  static const chatPattern = '/chat/:chatId';
  static const groupInfoPattern = '/chat/:chatId/info';
  static const newGroup = '/group/new';
  static const newGroupDetails = '/group/new/details';
  static const call = '/call';

  static String chat(String chatId) => '/chat/$chatId';
  static String groupInfo(String chatId) => '/chat/$chatId/info';
}
