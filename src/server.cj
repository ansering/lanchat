package lanchat

import std.collection.*
import std.sync.*
import std.random.*
import std.crypto.digest.*

/*
 * ============================================================================
 * server.cj —— 服务端
 * ----------------------------------------------------------------------------
 * 结构：
 *   User    账号数据
 *   Room    房间（成员用户名列表）
 *   Session 一条连接的运行时表示
 *   Server  全局状态与业务逻辑
 *
 * 并发约定（详见开发文档 §4.6）：
 *   - gLock 保护 users / sessions / rooms
 *   - session.writeLock 保护该连接的写操作
 *   - 持锁顺序：先 gLock，后 writeLock；锁内禁止阻塞 I/O
 * ============================================================================
 */

/* ------------------------------- 数据模型 ------------------------------- */

public class User {
    public let name: String
    public let salt: String
    public let hash: String

    public init(name: String, salt: String, hash: String) {
        this.name = name
        this.salt = salt
        this.hash = hash
    }
}

public class Room {
    public let name: String
    public let members = ArrayList<String>()

    public init(name: String) {
        this.name = name
    }
}

public class Session {
    public let socket: TcpSocket
    public var name: String = ""              /* 空表示未认证 */
    public var room: Option<String> = None
    public var lastSeen: Int64 = 0
    public let writeLock = Mutex()

    public init(socket: TcpSocket) {
        this.socket = socket
    }

    public func authenticated(): Bool {
        return !this.name.isEmpty()
    }
}

/* ------------------------------- 服务端 ------------------------------- */

public class Server {
    private let port: UInt16
    private let users = HashMap<String, User>()
    private let sessions = HashMap<String, Session>()
    private let rooms = HashMap<String, Room>()
    private let gLock = Mutex()

    public init(port: UInt16) {
        this.port = port
        /* 默认房间始终存在 */
        this.rooms.add(DEFAULT_ROOM, Room(DEFAULT_ROOM))
    }

    /* --------------------------- 启动与接入 --------------------------- */

    public func run(): Unit {
        let listener = createListener(this.port)   /* TODO(M0): 按实际 API 创建监听 */
        println("[server] listening on 0.0.0.0:${this.port}")
        startSweeper()
        while (true) {
            let sock = try {
                listener.accept()                  /* TODO(M0) */
            } catch (e: Exception) {
                continue
            }
            spawn { this.handleClient(sock) }
        }
    }

    private func handleClient(sock: TcpSocket): Unit {
        let sess = Session(sock)
        while (true) {
            let line = readLine(sock)
            match (line) {
                case None => break
                case Some(text) =>
                    if (text.isEmpty()) { continue }
                    sess.lastSeen = nowSeconds()
                    let obj = decode(text)
                    match (obj) {
                        case None =>
                            this.send(sess, errMsg(ERR_PROTOCOL_ERROR, "invalid json"))
                        case Some(m) =>
                            this.dispatch(sess, m)
                    }
            }
        }
        this.cleanup(sess)
    }

    /* --------------------------- 消息分发 --------------------------- */

    private func dispatch(sess: Session, msg: JsonObject): Unit {
        let typ = try { getStr(msg, "type") } catch (e: Exception) {
            this.send(sess, errMsg(ERR_PROTOCOL_ERROR, "missing type"))
            return
        }

        /* 未认证连接只允许 register / login / ping */
        if (!sess.authenticated() &&
            typ != MSG_REGISTER && typ != MSG_LOGIN && typ != MSG_PING) {
            this.send(sess, errMsg(ERR_NOT_AUTHENTICATED, "login required"))
            return
        }

        match (typ) {
            case MSG_REGISTER     => this.handleRegister(sess, msg)
            case MSG_LOGIN        => this.handleLogin(sess, msg)
            case MSG_LIST_ROOMS   => this.handleListRooms(sess)
            case MSG_CREATE_ROOM  => this.handleCreateRoom(sess, msg)
            case MSG_JOIN_ROOM    => this.handleJoinRoom(sess, msg)
            case MSG_LEAVE_ROOM   => this.handleLeaveRoom(sess, msg)
            case MSG_WHO          => this.handleWho(sess, msg)
            case MSG_SEND_ROOM    => this.handleSendRoom(sess, msg)
            case MSG_SEND_PRIVATE => this.handleSendPrivate(sess, msg)
            case MSG_PING         => this.send(sess, newMsg(MSG_PONG))
            case _                => this.send(sess, errMsg(ERR_PROTOCOL_ERROR, "unknown type"))
        }
    }

    /* --------------------------- 认证 --------------------------- */

    private func handleRegister(sess: Session, msg: JsonObject): Unit {
        let username = try { getStr(msg, "username") } catch (e: Exception) {
            this.send(sess, errMsg(ERR_PROTOCOL_ERROR, "username required"))
            return
        }
        let password = try { getStr(msg, "password") } catch (e: Exception) {
            this.send(sess, errMsg(ERR_PROTOCOL_ERROR, "password required"))
            return
        }
        if (!validUsername(username)) {
            this.send(sess, errMsg(ERR_PROTOCOL_ERROR, "invalid username"))
            return
        }
        if (!validPassword(password)) {
            this.send(sess, errMsg(ERR_PROTOCOL_ERROR, "invalid password"))
            return
        }

        synchronized(this.gLock) {
            if (this.users.contains(username)) {
                this.send(sess, errMsg(ERR_USERNAME_TAKEN, "username exists"))
                return
            }
            let salt = randomSalt()
            this.users.add(username, User(username, salt, sha256Hex(salt + password)))
        }
        this.send(sess, okMsg(MSG_REGISTER))
    }

    private func handleLogin(sess: Session, msg: JsonObject): Unit {
        let username = try { getStr(msg, "username") } catch (e: Exception) {
            this.send(sess, errMsg(ERR_PROTOCOL_ERROR, "username required"))
            return
        }
        let password = try { getStr(msg, "password") } catch (e: Exception) {
            this.send(sess, errMsg(ERR_PROTOCOL_ERROR, "password required"))
            return
        }

        var user: Option<User> = None
        var already: Option[Session] = None
        synchronized(this.gLock) {
            user = this.users.get(username)
            already = this.sessions.get(username)
        }

        match (user) {
            case None =>
                this.send(sess, errMsg(ERR_BAD_CREDENTIALS, "invalid username or password"))
                return
            case Some(u) =>
                if (sha256Hex(u.salt + password) != u.hash) {
                    this.send(sess, errMsg(ERR_BAD_CREDENTIALS, "invalid username or password"))
                    return
                }
                /* 踢掉旧会话（同名重复登录） */
                match (already) {
                    case Some(old) => this.cleanup(old)
                    case None => ()
                }
                sess.name = username
                synchronized(this.gLock) {
                    this.sessions.add(username, sess)
                }
                let rooms = this.roomNames()
                let reply = newMsg(MSG_LOGIN_OK)
                putStr(reply, "username", username)
                putStrArray(reply, "rooms", rooms)
                this.send(sess, reply)
        }
    }

    /* --------------------------- 房间 --------------------------- */

    private func roomNames(): ArrayList<String> {
        let names = ArrayList<String>()
        synchronized(this.gLock) {
            for ((k, _) in this.rooms) {
                names.add(k)
            }
        }
        return names
    }

    private func handleListRooms(sess: Session): Unit {
        let reply = newMsg(MSG_ROOM_LIST)
        putStrArray(reply, "rooms", this.roomNames())
        this.send(sess, reply)
    }

    private func handleCreateRoom(sess: Session, msg: JsonObject): Unit {
        let room = try { getStr(msg, "room") } catch (e: Exception) {
            this.send(sess, errMsg(ERR_PROTOCOL_ERROR, "room required"))
            return
        }
        if (!validRoom(room)) {
            this.send(sess, errMsg(ERR_PROTOCOL_ERROR, "invalid room"))
            return
        }
        synchronized(this.gLock) {
            if (!this.rooms.contains(room)) {
                this.rooms.add(room, Room(room))
            }
        }
        this.send(sess, okMsg(MSG_CREATE_ROOM))
    }

    private func handleJoinRoom(sess: Session, msg: JsonObject): Unit {
        let room = try { getStr(msg, "room") } catch (e: Exception) {
            this.send(sess, errMsg(ERR_PROTOCOL_ERROR, "room required"))
            return
        }
        var exists = false
        synchronized(this.gLock) {
            exists = this.rooms.contains(room)
        }
        if (!exists) {
            this.send(sess, errMsg(ERR_ROOM_NOT_FOUND, "room not found"))
            return
        }
        if (sess.room == Some(room)) {
            this.send(sess, okMsg(MSG_JOIN_ROOM))     /* 已在房间，幂等返回 */
            return
        }
        /* 先离开旧房间 */
        if (sess.room != None) {
            this.leaveCurrentRoom(sess)
        }
        synchronized(this.gLock) {
            match (this.rooms.get(room)) {
                case Some(r) => r.members.add(sess.name)
                case None => ()
            }
        }
        sess.room = Some(room)
        this.send(sess, okMsg(MSG_JOIN_ROOM))
        this.broadcast(room, systemMsg("${sess.name} 加入了 ${room}"))
    }

    private func handleLeaveRoom(sess: Session, msg: JsonObject): Unit {
        let room = try { getStr(msg, "room") } catch (e: Exception) {
            this.send(sess, errMsg(ERR_PROTOCOL_ERROR, "room required"))
            return
        }
        if (sess.room != Some(room)) {
            this.send(sess, errMsg(ERR_ROOM_NOT_FOUND, "not in room"))
            return
        }
        this.leaveCurrentRoom(sess)
        this.send(sess, okMsg(MSG_LEAVE_ROOM))
    }

    private func leaveCurrentRoom(sess: Session): Unit {
        match (sess.room) {
            case Some(room) =>
                synchronized(this.gLock) {
                    match (this.rooms.get(room)) {
                        case Some(r) => r.members.remove(sess.name)
                        case None => ()
                    }
                }
                sess.room = None
                this.broadcast(room, systemMsg("${sess.name} 离开了 ${room}"))
            case None => ()
        }
    }

    private func handleWho(sess: Session, msg: JsonObject): Unit {
        let room = match (getOptStr(msg, "room")) {
            case Some(r) => r
            case None => match (sess.room) {
                case Some(r) => r
                case None => ""
            }
        }
        if (room.isEmpty()) {
            this.send(sess, errMsg(ERR_ROOM_NOT_FOUND, "not in room"))
            return
        }
        let members = ArrayList<String>()
        synchronized(this.gLock) {
            match (this.rooms.get(room)) {
                case Some(r) =>
                    for (m in r.members) { members.add(m) }
                case None => ()
            }
        }
        let reply = newMsg(MSG_USER_LIST)
        putStr(reply, "room", room)
        putStrArray(reply, "users", members)
        this.send(sess, reply)
    }

    /* --------------------------- 消息 --------------------------- */

    private func handleSendRoom(sess: Session, msg: JsonObject): Unit {
        let text = try { getStr(msg, "text") } catch (e: Exception) {
            this.send(sess, errMsg(ERR_PROTOCOL_ERROR, "text required"))
            return
        }
        if (!validText(text)) {
            this.send(sess, errMsg(ERR_PROTOCOL_ERROR, "invalid text"))
            return
        }
        let room = match (sess.room) {
            case Some(r) => r
            case None =>
                this.send(sess, errMsg(ERR_ROOM_NOT_FOUND, "join a room first"))
                return
        }
        this.broadcast(room, chatMsg(SCOPE_ROOM, room, sess.name, "", text))
    }

    private func handleSendPrivate(sess: Session, msg: JsonObject): Unit {
        let to = try { getStr(msg, "to") } catch (e: Exception) {
            this.send(sess, errMsg(ERR_PROTOCOL_ERROR, "to required"))
            return
        }
        let text = try { getStr(msg, "text") } catch (e: Exception) {
            this.send(sess, errMsg(ERR_PROTOCOL_ERROR, "text required"))
            return
        }
        if (!validText(text)) {
            this.send(sess, errMsg(ERR_PROTOCOL_ERROR, "invalid text"))
            return
        }
        var target: Option<Session> = None
        synchronized(this.gLock) {
            target = this.sessions.get(to)
        }
        match (target) {
            case None =>
                this.send(sess, errMsg(ERR_USER_OFFLINE, "user offline"))
            case Some(t) =>
                this.send(t, chatMsg(SCOPE_PRIVATE, "", sess.name, to, text))
                this.send(sess, chatMsg(SCOPE_PRIVATE, "", sess.name, to, text))
        }
    }

    /* --------------------------- 发送与广播 --------------------------- */

    private func send(sess: Session, msg: JsonObject): Unit {
        synchronized(sess.writeLock) {
            writeLine(sess.socket, encode(msg))
        }
    }

    private func broadcast(room: String, msg: JsonObject): Unit {
        /* 先在锁内收集目标，释放锁后再逐个发送，避免持锁 I/O */
        let targets = ArrayList<Session>()
        synchronized(this.gLock) {
            match (this.rooms.get(room)) {
                case Some(r) =>
                    for (name in r.members) {
                        match (this.sessions.get(name)) {
                            case Some(s) => targets.add(s)
                            case None => ()
                        }
                    }
                case None => ()
            }
        }
        for (s in targets) {
            this.send(s, msg)
        }
    }

    /* --------------------------- 清理与心跳 --------------------------- */

    public func cleanup(sess: Session): Unit {
        if (!sess.authenticated()) {
            return
        }
        this.leaveCurrentRoom(sess)
        synchronized(this.gLock) {
            this.sessions.remove(sess.name)
        }
        try { sess.socket.close() } catch (e: Exception) { () }
        println("[server] ${sess.name} disconnected")
    }

    private func startSweeper(): Unit {
        spawn {
            while (true) {
                sleep(Duration.second * 30)
                let now = nowSeconds()
                let stale = ArrayList<Session>()
                synchronized(this.gLock) {
                    for ((_, s) in this.sessions) {
                        if (now - s.lastSeen > 90) {
                            stale.add(s)
                        }
                    }
                }
                for (s in stale) {
                    this.cleanup(s)
                }
            }
        }
    }
}

/* =========================================================================
 * 认证辅助（TODO(M0)：按实际 std.crypto.digest / std.random API 校准）
 * ========================================================================= */

public func randomSalt(): String {
    let r = Random()
    let sb = StringBuilder()
    for (_ in 0..16) {
        sb.append(r.nextInt(UInt32(256)).toString(radix: 16))
    }
    return sb.toString()
}

public func sha256Hex(input: String): String {
    let digest = SHA256.digest(input.toArray())   /* TODO(M0): 按实际 API 校准 */
    let sb = StringBuilder()
    for (b in digest) {
        sb.append(UInt32(b).toString(radix: 16))
    }
    return sb.toString()
}

/* TODO(M0)：按实际 stdx.net API 创建监听套接字 */
public func createListener(port: UInt16): TcpServerSocket {
    return TcpServerSocket(port)
}
