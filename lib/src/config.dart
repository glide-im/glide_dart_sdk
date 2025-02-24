class Configs {
  // static const String apiBaseUrl = "http://127.0.0.1:8081/api/";
  static const String apiBaseUrl = "https://api.im.dengzii.com/api/";

  static const String wsUrl = "ws://127.0.0.1:8083/ws";
  // static const String wsUrl = "wss://ws.im.dengzii.com/ws";

  // await server ack after send message
  static bool awaitServerMessageAck = true;

  static int typingEventInterval = 1000;
}
