class UserInfoBean {
  final num uid;
  final String nickName;
  final String account;
  final String avatar;

  UserInfoBean({
    required this.uid,
    required this.nickName,
    required this.account,
    required this.avatar,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nick_name': nickName,
      'account': account,
      'avatar': avatar,
    };
  }

  static UserInfoBean fromMap(dynamic map) {
    return UserInfoBean(
      uid: map['uid'] as num,
      nickName: map['nick_name'] as String,
      account: map['account'] as String,
      avatar: map['avatar'] as String,
    );
  }

  UserInfoBean copyWith({
    num? uid,
    String? nickName,
    String? account,
    String? avatar,
  }) {
    return UserInfoBean(
      uid: uid ?? this.uid,
      nickName: nickName ?? this.nickName,
      account: account ?? this.account,
      avatar: avatar ?? this.avatar,
    );
  }
}
