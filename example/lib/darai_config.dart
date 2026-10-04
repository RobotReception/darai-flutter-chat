import 'package:darai_chat/darai_chat.dart';

// Copy only public connection data from Darai. Never put signing secrets here.
const daraiConfig = DaraiChatConfig(
  baseUrl: String.fromEnvironment('DARAI_BASE_URL'),
  cId: String.fromEnvironment('DARAI_CHANNEL_ID'),
  appId: String.fromEnvironment('DARAI_APP_ID'),
);
