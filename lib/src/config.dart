class Configs {
  static const String apiBaseUrl = "https://intercom.ink/api/";
  static const String wsUrl = "wss://intercom.ink/ws";

  // static const String wsUrl = "ws://localhost:8083/ws";

  // await server ack after send message
  static bool awaitServerMessageAck = true;

  static int typingEventInterval = 1000;
}
