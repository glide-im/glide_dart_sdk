import 'bean/ticket_bean.dart';
import 'http.dart';

class SessionApi {

  const SessionApi();

  Future<TicketBean> getTicket(String id) =>
      Http.post("session/ticket", {"To": id}, TicketBean.fromJson);

  Future getBlackList() => Http.get("session/blacklist");
}
