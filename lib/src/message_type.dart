part of 'message.dart';

class UnknownMessageType extends MessageType<String> {
  static const value = -1;

  static final UnknownMessageType instance = UnknownMessageType();

  UnknownMessageType() : super(type: value, name: 'unknown', isUserMessage: false);

  @override
  String contentDescription(String data) => '[Unknown]';

  @override
  String decode(dynamic data) => data.toString();

  @override
  dynamic encode(String data) => data;
}

class TextMessageType extends MessageType<String> {
  static const value = 1;

  static final TextMessageType instance = TextMessageType();

  TextMessageType() : super(type: value, name: 'text');
}

class ImageMessageType extends MessageType<String> {
  static const value = 1002;

  static final ImageMessageType instance = ImageMessageType();

  ImageMessageType() : super(type: value, name: 'image');

  @override
  String contentDescription(String data) => '[Image]';
}

class EnterMessageType extends MessageType<String> {
  static const value = 2002;

  static final EnterMessageType instance = EnterMessageType();

  EnterMessageType() : super(type: value, name: 'enter', isUserMessage: false);

  @override
  String contentDescription(String data) => '[Enter]';

  @override
  String decode(dynamic data) => (data as Map<String, dynamic>)['uid'] as String;
}

class LeaveMessageType extends MessageType<String> {
  static const value = 2001;

  static final LeaveMessageType instance = LeaveMessageType();

  LeaveMessageType() : super(type: value, name: 'leave', isUserMessage: false);

  @override
  String contentDescription(String data) => '[Leave]';

  @override
  String decode(dynamic data) => (data as Map<String, String>)['uid'] as String;
}

class NotifyMembersMessageType extends MessageType<List<String>> {
  static const value = 2005;

  static final NotifyMembersMessageType instance = NotifyMembersMessageType();

  NotifyMembersMessageType() : super(type: value, name: 'group.notify.members', isUserMessage: false);

  @override
  List<String> decode(dynamic data) => (data['members'] as Iterable).map((it) => it as String).toList();
}

class StreamTextMessageType extends MessageType<String> {
  static const value = 10011;

  static final StreamTextMessageType instance = StreamTextMessageType();

  StreamTextMessageType() : super(type: value, name: 'stream-text', isUserMessage: false);
}

class TypingMessageType extends MessageType<Map<String, dynamic>> {
  static const value = 10020;

  static final TypingMessageType instance = TypingMessageType();

  TypingMessageType() : super(type: value, name: 'typing', isUserMessage: false);
}

class FileMessageType extends MessageType<FileMessageBody> {
  static const value = 10030;

  static final FileMessageType instance = FileMessageType();

  FileMessageType() : super(type: value, name: 'file');

  @override
  FileMessageBody decode(dynamic data) => FileMessageBody.fromMap(data as Map<String, dynamic>);

  @override
  dynamic encode(FileMessageBody data) => data.toMap();
}

class CustomMessageType extends MessageType<Map<String, dynamic>> {
  static const value = 10040;

  static final FileMessageType instance = FileMessageType();

  CustomMessageType() : super(type: value, name: 'custom', isUserMessage: false);

  @override
  Map<String, dynamic> decode(dynamic data) => JsonDecoder().convert(data as String);

  @override
  dynamic encode(Map<String, dynamic> data) => JsonEncoder().convert(data);
}

enum FileType {
  image(1),
  audio(2),
  video(3),
  document(4),
  unknown(-1);

  final int value;

  const FileType(this.value);

  static FileType of(String name) {
    final ext = name.split('.').last;
    switch (ext) {
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
        return FileType.image;
      case 'mp4':
      case 'avi':
        return FileType.video;
      case 'pdf':
      case 'ppt':
      case 'doc':
      case 'xls':
      case 'pptx':
      case 'docx':
      case 'xlsx':
        return FileType.document;
      case 'mp3':
      case 'wav':
      case 'ogg':
      case 'm4a':
        return FileType.audio;
      default:
        return FileType.unknown;
    }
  }

  static final Map<num, FileType> _map = {for (var type in FileType.values) type.value: type};

  static FileType valueOf(int value) {
    return _map[value] ?? FileType.unknown;
  }
}

class FileMessageBody {
  final String name;
  final String url;
  final num size;
  final FileType type;

  FileMessageBody({
    required this.name,
    required this.url,
    required this.size,
    required this.type,
  });

  @override
  String toString() {
    return 'FileMessageBody{name: $name, url: $url, size: $size, type: $type}';
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'url': url,
      'size': size,
      'type': type.value,
    };
  }

  factory FileMessageBody.fromMap(Map<String, dynamic> map) {
    return FileMessageBody(
      name: map['name'] as String,
      url: map['url'] as String,
      size: map['size'] as num,
      type: FileType.valueOf(map['type']),
    );
  }
}
