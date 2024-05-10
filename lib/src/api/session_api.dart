import 'bean/ticket_bean.dart';
import 'http.dart';

class SessionApi {
  static Future<TicketBean> getTicket(String id) =>
      Http.post("session/ticket", {"To": id}, TicketBean.fromJson);

  static Future getBlackList() => Http.get("session/blacklist");
}
