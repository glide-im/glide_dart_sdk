class AuthBean {
  AuthBean({
    this.token,
    this.uid,
    this.servers,
    this.nickName,
    this.app,
    this.email,
    this.phone,
    this.device,
    this.credential,
  });

  AuthBean.fromJson(dynamic json) {
    token = json['token'];
    uid = json['uid'];
    servers = json['servers'] != null ? json['servers'].cast<String>() : [];
    nickName = json['nick_name'];
    app = json['app'] != null ? App.fromJson(json['app']) : null;
    email = json['email'];
    phone = json['phone'];
    device = json['device'];
    credential = json['credential'] != null
        ? Credential.fromJson(json['credential'])
        : null;
  }

  String? token;
  num? uid;
  List<String>? servers;
  String? nickName;
  App? app;
  String? email;
  String? phone;
  num? device;
  Credential? credential;

  AuthBean copyWith({
    String? token,
    num? uid,
    List<String>? servers,
    String? nickName,
    App? app,
    String? email,
    String? phone,
    num? device,
    Credential? credential,
  }) =>
      AuthBean(
        token: token ?? this.token,
        uid: uid ?? this.uid,
        servers: servers ?? this.servers,
        nickName: nickName ?? this.nickName,
        app: app ?? this.app,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        device: device ?? this.device,
        credential: credential ?? this.credential,
      );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['token'] = token;
    map['uid'] = uid;
    map['servers'] = servers;
    map['nick_name'] = nickName;
    if (app != null) {
      map['app'] = app?.toJson();
    }
    map['email'] = email;
    map['phone'] = phone;
    map['device'] = device;
    if (credential != null) {
      map['credential'] = credential?.toJson();
    }
    return map;
  }
}

class Credential {
  Credential({
    this.version,
    this.credential,
  });

  Credential.fromJson(dynamic json) {
    version = json['version'];
    credential = json['credential'];
  }

  num? version;
  String? credential;

  Credential copyWith({
    num? version,
    String? credential,
  }) =>
      Credential(
        version: version ?? this.version,
        credential: credential ?? this.credential,
      );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['version'] = version;
    map['credential'] = credential;
    return map;
  }
}

class App {
  App({
    this.id,
    this.name,
    this.uid,
    this.status,
    this.logo,
    this.email,
    this.phone,
    this.host,
  });

  App.fromJson(dynamic json) {
    id = json['id'];
    name = json['name'];
    uid = json['uid'];
    status = json['status'];
    logo = json['logo'];
    email = json['email'];
    phone = json['phone'];
    host = json['host'];
  }

  num? id;
  String? name;
  num? uid;
  num? status;
  String? logo;
  String? email;
  String? phone;
  String? host;

  App copyWith({
    num? id,
    String? name,
    num? uid,
    num? status,
    String? logo,
    String? email,
    String? phone,
    String? host,
  }) =>
      App(
        id: id ?? this.id,
        name: name ?? this.name,
        uid: uid ?? this.uid,
        status: status ?? this.status,
        logo: logo ?? this.logo,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        host: host ?? this.host,
      );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['name'] = name;
    map['uid'] = uid;
    map['status'] = status;
    map['logo'] = logo;
    map['email'] = email;
    map['phone'] = phone;
    map['host'] = host;
    return map;
  }
}
