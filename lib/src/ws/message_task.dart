import 'dart:collection';

class MessageTaskException implements Exception {
  final String message;

  MessageTaskException(this.message);

  @override
  String toString() {
    return 'MessageTaskException{message: $message}';
  }
}

/// 消息发送任务步骤
class TaskStep {
  final String name;
  int elapsedTime = 0;
  final Future Function(dynamic) _fn;

  TaskStep(this.name, this._fn);

  Future doStep(dynamic data) async {
    return await _fn(data);
  }

  @override
  String toString() {
    return 'TaskStep{name: $name, _fn: $_fn}';
  }
}

/// 表示一个可取消的异步消息发送任务, 包含发送过程中的多个步骤 [TaskStep], 例如重试, 重连.
///
/// 每个 [TaskStep] 接受一个类型为 [dynamic] 的参数, 值为上一个 step 的结果, 如果没有值则为 null.
/// 通过方法 [addStep] 添加步骤, 返回一个 [Future], 当调用 [execute] 方法
/// 时会按添加顺序执行所有步骤, 如果中间使用 [cancel] 方法取消任务或执行某一个步骤出现异常, 则会停止执行,
/// 除取消以外的异常 [onError] 将被回调, 同时异常也可以在 [execute] 返回的 [Future] 中捕获.
///
/// [T] 泛型 T 必须为最后一个步骤中结果的类型
class MessageTask<T> {
  static const tag = "MessageTask";

  bool _canceled = false;
  bool _finished = false;
  String _id = "";
  int startTime = 0;

  final List<Function()> _onCancel = [];
  final List<Function()> _onComplete = [];
  final List<Function(dynamic e, TaskStep? step)> _onError = [];
  final List<Function()> _onExecute = [];

  final Queue<TaskStep> _queue = Queue();

  MessageTask([String? id]) {
    _id = id ?? hashCode.toString();
  }

  /// 取消当前任务, 若已取消或已完成则不会有操作.
  void cancel() {
    if (_canceled || _finished) {
      return;
    }
    _canceled = true;
    for (var onCancel in _onCancel) {
      try {
        onCancel();
      } catch (e, t) {
        // Logger.errTrace(tag, e, t);
      }
    }
  }

  /// 添加一个步骤.
  /// 当执行 [execute] 时调用 [fn] 并等待 [Future].
  ///
  /// [fn] 获取步骤的回调方法, 返回包含当前步骤结果的 [Future].
  /// [name] 用于标识不同步骤.
  void addStep(Future Function(dynamic) fn, {String? name}) {
    final step = TaskStep(name ?? fn.hashCode.toString(), fn);
    _queue.add(step);
  }

  void nextRetry(Future Function(dynamic) next) {
    // TODO: 2022-8-10 11:17:11 add retry logic
    throw Exception("not implemented");
  }

  void onExecute(Function() onExecute) {
    _onExecute.add(onExecute);
  }

  void onCancel(Function() onCancel) {
    _onCancel.add(onCancel);
  }

  /// 添加执行异常回调.
  ///
  /// 任务取消异常不会回调此方法.
  void onError(Function([dynamic e, TaskStep? step]) onError) {
    _onError.add(onError);
  }

  void onComplete(Function() onComplete) {
    _onComplete.add(onComplete);
  }

  /// 执行当前任务, 依次调用并等待所有步骤的结果.
  ///
  /// 如果当前任务已取消或已执行, 将抛出异常 [MessageTaskException].
  /// 执行中若调用 [cancel] 取消任务, 将抛出 [MessageTaskException].
  ///
  /// 取消的异常不会在 onError 中调用
  Future<T> execute() async {
    if (_canceled) {
      _throw("task canceled");
    }
    if (_finished) {
      _throw("task finished");
    }
    for (var onExec in _onExecute) {
      onExec();
    }
    startTime = DateTime.now().millisecondsSinceEpoch;

    TaskStep? s;
    int startAt = 0;
    try {
      dynamic result;
      for (var step in _queue) {
        if (_canceled) {
          _throw("task canceled");
        }
        s = step;
        startAt = DateTime.now().millisecondsSinceEpoch;
        result = await step.doStep(result);
        step.elapsedTime = DateTime.now().millisecondsSinceEpoch - startAt;
      }
      if (_canceled) {
        _throw("task canceled");
      }
      return result;
    } on MessageTaskException catch (_) {
      // 取消异常不回调 onError
      s?.elapsedTime = DateTime.now().millisecondsSinceEpoch - startAt;
      rethrow;
    } catch (e) {
      s?.elapsedTime = DateTime.now().millisecondsSinceEpoch - startAt;
      for (var onError in _onError) {
        onError(e, s);
      }
      rethrow;
    } finally {
      _finished = true;
      for (var onComplete in _onComplete) {
        try {
          onComplete();
        } catch (e, t) {
          // Logger.errTrace(tag, e, t);
        }
      }
      // _onCancel.clear();
      // _onComplete.clear();
      // _onError.clear();
      // _onExec.clear();
    }
  }

  void _throw(String msg) {
    throw MessageTaskException(msg);
  }

  @override
  String toString() {
    return 'MessageTask{_id: $_id, _canceled: $_canceled, _finished: $_finished, _steps: ${_queue.length}';
  }
}
