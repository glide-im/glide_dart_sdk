class TicketBean {
  final String ticket;

  TicketBean({required this.ticket});

  factory TicketBean.fromJson(dynamic json) {
    return TicketBean(
      ticket: json['Ticket'],
    );
  }
}
