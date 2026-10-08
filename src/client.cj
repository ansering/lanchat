package lanchat

import std.net.*
import std.sync.*
import stdx.encoding.json.*

/* 主线程处理登录和输入；登录成功后读线程持续接收服务端事件。 */
public class Client {
    private let host: String
    private let port: UInt16
    private let writeLock = Mutex()
    private let outLock = Mutex()

    private var socket: Option<TcpSocket> = None
    private var reader: Option<LineReader> = None
    private var running = false
    private var name = ""

    public init(host: String, port: UInt16) {
        this.host = host
        this.port = port
    }

    /* connect → login → 确认 login_ok → 启动读线程 → 输入循环 → close。 */
    public func run(): Unit { todo("Client.run") }
    private func connect(): Unit { todo("Client.connect") }

    /* 从终端读取已发放的账号与口令；失败时不进入输入循环。 */
    private func authPhase(): Unit { todo("Client.authPhase") }

    private func readerLoop(): Unit { todo("Client.readerLoop") }
    private func handle(msg: JsonObject): Unit { todo("Client.handle") }

    /* 普通文本发 general；仅支持 /who、/msg <用户名> <内容>、/quit。 */
    private func inputLoop(): Unit { todo("Client.inputLoop") }

    private func send(msg: JsonObject): Unit { todo("Client.send") }
    private func printLine(text: String): Unit { todo("Client.printLine") }
    private func close(): Unit { todo("Client.close") }
}
