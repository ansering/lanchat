package lanchat

import std.collection.*
import std.sync.*
import std.console.*

/*
 * ============================================================================
 * client.cj —— 客户端（滚动式终端界面）
 * ----------------------------------------------------------------------------
 * 线程：
 *   - 主线程：读取键盘输入并发送
 *   - 读线程：接收服务端消息并打印
 *   - outLock：保护终端输出，保证整行原子打印
 * ============================================================================
 */

public class Client {
    private let host: String
    private let port: UInt16
    private let socket: TcpSocket
    private let writeLock = Mutex()
    private let outLock = Mutex()

    private var running = true
    private var name = ""
    private var room = ""

    public init(host: String, port: UInt16) {
        this.host = host
        this.port = port
        this.socket = connectSocket(host, port)   /* TODO(M0) */
    }

    /* ------------------------------ 输出 ------------------------------ */

    private func printLine(text: String): Unit {
        synchronized(this.outLock) {
            println(text)
        }
    }

    private func printPrompt(): Unit {
        synchronized(this.outLock) {
            print("> ")
        }
    }

    /* ------------------------------ 发送 ------------------------------ */

    private func send(msg: JsonObject): Unit {
        synchronized(this.writeLock) {
            writeLine(this.socket, encode(msg))
        }
    }

    /* ------------------------------ 主流程 ------------------------------ */

    public func run(): Unit {
        println("已连接到 ${this.host}:${this.port}")

        /* 认证阶段（在进入消息循环前完成） */
        this.authPhase()

        /* 进入默认房间 */
        let join = newMsg(MSG_JOIN_ROOM)
        putStr(join, "room", DEFAULT_ROOM)
        this.send(join)
        this.room = DEFAULT_ROOM

        /* 启动读线程 */
        spawn { this.readerLoop() }

        /* 主线程：输入循环 */
        this.inputLoop()
    }

    private func authPhase(): Unit {
        while (true) {
            printLine("1) 注册   2) 登录")
            printPrompt()
            let choice = Console.readln() ?? ""
            print("用户名: ")
            let user = Console.readln() ?? ""
            print("密码: ")
            let pass = Console.readln() ?? ""

            let msg = newMsg(if (choice == "1") { MSG_REGISTER } else { MSG_LOGIN })
            putStr(msg, "username", user.trimAscii())
            putStr(msg, "password", pass)
            this.send(msg)

            /* 等待认证结果 */
            match (this.waitAuth()) {
                case Some(loginName) =>
                    this.name = loginName
                    this.printLine("登录成功，欢迎 ${this.name}")
                    return
                case None => ()
            }
        }
    }

    private func waitAuth(): Option<String> {
        while (true) {
            let line = readLine(this.socket)
            match (line) {
                case None => return None
                case Some(text) =>
                    match (decode(text)) {
                        case None => ()
                        case Some(msg) =>
                            let typ = try { getStr(msg, "type") } catch (e: Exception) { "" }
                            match (typ) {
                                case MSG_LOGIN_OK =>
                                    return Some(getStr(msg, "username"))
                                case MSG_OK =>
                                    this.printLine("注册成功，请重新登录")
                                case MSG_ERROR =>
                                    this.printLine("[错误] ${getStr(msg, "message")}")
                                case _ => ()
                            }
                    }
            }
        }
    }

    /* ------------------------------ 读线程 ------------------------------ */

    private func readerLoop(): Unit {
        while (this.running) {
            let line = readLine(this.socket)
            match (line) {
                case None =>
                    this.printLine("[提示] 与服务器断开连接")
                    this.running = false
                    return
                case Some(text) =>
                    match (decode(text)) {
                        case None => ()
                        case Some(msg) => this.handle(msg)
                    }
            }
        }
    }

    private func handle(msg: JsonObject): Unit {
        let typ = try { getStr(msg, "type") } catch (e: Exception) { return }
        match (typ) {
            case MSG_MESSAGE =>
                let scope = getStr(msg, "scope")
                let from = getStr(msg, "from")
                let text = getStr(msg, "text")
                let ts = formatTime(getInt(msg, "ts"))
                if (scope == SCOPE_PRIVATE) {
                    this.printLine("[${ts}] [私聊]<${from}> ${text}")
                } else {
                    this.printLine("[${ts}] <${from}> ${text}")
                }
            case MSG_SYSTEM =>
                this.printLine("[${formatTime(getInt(msg, "ts"))}] * ${getStr(msg, "text")}")
            case MSG_ROOM_LIST =>
                let rooms = getStrArray(msg, "rooms")
                this.printLine("房间: ${joinStrings(rooms, ", ")}")
            case MSG_USER_LIST =>
                let users = getStrArray(msg, "users")
                this.printLine("[${getStr(msg, "room")}] 在线: ${joinStrings(users, ", ")}")
            case MSG_ERROR =>
                this.printLine("[错误] ${getStr(msg, "message")}")
            case MSG_PONG => ()
            case _ => ()
        }
    }

    /* ------------------------------ 输入循环 ------------------------------ */

    private func inputLoop(): Unit {
        while (this.running) {
            this.printPrompt()
            let line = Console.readln() ?? ""
            let text = line.trimAscii()
            if (text.isEmpty()) { continue }

            if (text == "/quit") {
                this.running = false
                break
            } else if (text.startsWith("/join ")) {
                let r = text[6..]
                let msg = newMsg(MSG_JOIN_ROOM)
                putStr(msg, "room", r)
                this.send(msg)
                this.room = r
            } else if (text == "/rooms") {
                this.send(newMsg(MSG_LIST_ROOMS))
            } else if (text == "/who") {
                let msg = newMsg(MSG_WHO)
                putStr(msg, "room", this.room)
                this.send(msg)
            } else if (text.startsWith("/msg ")) {
                let rest = text[5..]
                let parts = splitFirst(rest, " ")
                match (parts) {
                    case Some((to, body)) =>
                        let msg = newMsg(MSG_SEND_PRIVATE)
                        putStr(msg, "to", to)
                        putStr(msg, "text", body)
                        this.send(msg)
                    case None =>
                        this.printLine("[错误] 用法: /msg <user> <text>")
                }
            } else {
                let msg = newMsg(MSG_SEND_ROOM)
                putStr(msg, "room", this.room)
                putStr(msg, "text", text)
                this.send(msg)
            }
        }
        try { this.socket.close() } catch (e: Exception) { () }
    }
}

/* =========================================================================
 * 客户端辅助（TODO(M0)：按实际 API 校准）
 * ========================================================================= */

public func connectSocket(host: String, port: UInt16): TcpSocket {
    return TcpSocket(host, port)
}

public func joinStrings(items: ArrayList<String>, sep: String): String {
    let sb = StringBuilder()
    var first = true
    for (s in items) {
        if (!first) { sb.append(sep) }
        sb.append(s)
        first = false
    }
    return sb.toString()
}

public func splitFirst(s: String, sep: String): Option<(String, String)> {
    let idx = s.indexOf(sep)
    match (idx) {
        case Some(i) => return Some((s[0..i], s[i + sep.size..]))
        case None => return None
    }
}

public func formatTime(ts: Int64): String {
    /* TODO(M0)：按实际 API 将 Unix 秒格式化为 HH:MM */
    return DateTime.ofUnixTimeStamp(ts, TimeZone.current()).toString()
}
