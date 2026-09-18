package lanchat

import std.collection.*
import stdx.encoding.json.*
import stdx.net.*
import std.time.*

/*
 * ============================================================================
 * protocol.cj —— 通信协议的唯一实现入口
 * ----------------------------------------------------------------------------
 * 本文件集中了：
 *   1) 消息类型 / 错误码常量
 *   2) 字段校验规则
 *   3) JSON 编解码（按行分隔）
 *   4) 传输层读写（按行分帧）
 *
 * 【M0 校准点】标记为 TODO(M0) 的函数依赖实际 SDK 的 stdx API；
 * 只需修改本文件即可适配，其余模块不受影响。
 * ============================================================================
 */

/* ------------------------------- 消息类型 ------------------------------- */
public let MSG_REGISTER     = "register"
public let MSG_LOGIN        = "login"
public let MSG_LIST_ROOMS   = "list_rooms"
public let MSG_CREATE_ROOM  = "create_room"
public let MSG_JOIN_ROOM    = "join_room"
public let MSG_LEAVE_ROOM   = "leave_room"
public let MSG_WHO          = "who"
public let MSG_SEND_ROOM    = "send_room"
public let MSG_SEND_PRIVATE = "send_private"
public let MSG_PING         = "ping"

public let MSG_OK           = "ok"
public let MSG_ERROR        = "error"
public let MSG_LOGIN_OK     = "login_ok"
public let MSG_ROOM_LIST    = "room_list"
public let MSG_MESSAGE      = "message"
public let MSG_SYSTEM       = "system"
public let MSG_USER_LIST    = "user_list"
public let MSG_PONG         = "pong"

/* ------------------------------- 作用域 ------------------------------- */
public let SCOPE_ROOM    = "room"
public let SCOPE_PRIVATE = "private"

/* ------------------------------- 错误码 ------------------------------- */
public let ERR_NOT_AUTHENTICATED = 1001
public let ERR_USERNAME_TAKEN    = 1002
public let ERR_BAD_CREDENTIALS   = 1003
public let ERR_ROOM_NOT_FOUND    = 1004
public let ERR_USER_OFFLINE      = 1005
public let ERR_PROTOCOL_ERROR    = 1006
public let ERR_INTERNAL_ERROR    = 1099

/* ------------------------------- 限制值 ------------------------------- */
public let MAX_LINE_SIZE  = 64 * 1024   /* 单行最大字节数 */
public let MAX_TEXT_LEN   = 2000
public let MAX_ROOM_LEN   = 32
public let MAX_USER_LEN   = 16
public let MIN_USER_LEN   = 3
public let MIN_PASS_LEN   = 6
public let MAX_PASS_LEN   = 64
public let DEFAULT_ROOM   = "general"

/* =========================================================================
 * 一、字段校验
 * ========================================================================= */

public func validUsername(s: String): Bool {
    let n = s.size
    if (n < MIN_USER_LEN || n > MAX_USER_LEN) { return false }
    for (c in s) {
        let ok = (c >= r'a' && c <= r'z') || (c >= r'A' && c <= r'Z') ||
                 (c >= r'0' && c <= r'9') || c == r'_'
        if (!ok) { return false }
    }
    return true
}

public func validPassword(s: String): Bool {
    let n = s.size
    return n >= MIN_PASS_LEN && n <= MAX_PASS_LEN
}

public func validRoom(s: String): Bool {
    let n = s.size
    if (n == 0 || n > MAX_ROOM_LEN) { return false }
    for (c in s) {
        let ok = (c >= r'a' && c <= r'z') || (c >= r'A' && c <= r'Z') ||
                 (c >= r'0' && c <= r'9') || c == r'_' || c == r'-'
        if (!ok) { return false }
    }
    return true
}

public func validText(s: String): Bool {
    let n = s.size
    if (n == 0 || n > MAX_TEXT_LEN) { return false }
    return !s.trimAscii().isEmpty()
}

/* =========================================================================
 * 二、JSON 编解码（TODO(M0)：按实际 stdx.encoding.json API 校准）
 * ========================================================================= */

public func encode(obj: JsonObject): String {
    /* 序列化为一行 JSON，并追加换行符 */
    return obj.toString() + "\n"
}

public func decode(line: String): Option<JsonObject> {
    try {
        let v = JsonValue.fromStr(line)
        match (v) {
            case o: JsonObject => return Some(o)
            case _ => return None
        }
    } catch (e: Exception) {
        return None
    }
}

public func newMsg(typ: String): JsonObject {
    let o = JsonObject()
    o.add("type", JsonString(typ))
    return o
}

public func putStr(o: JsonObject, key: String, value: String): Unit {
    o.add(key, JsonString(value))
}

public func putInt(o: JsonObject, key: String, value: Int64): Unit {
    o.add(key, JsonInt(value))
}

public func putStrArray(o: JsonObject, key: String, values: ArrayList<String>): Unit {
    let arr = JsonArray()
    for (v in values) {
        arr.add(JsonString(v))
    }
    o.add(key, arr)
}

public func getStr(o: JsonObject, key: String): String {
    match (o.get(key)) {
        case Some(v: JsonString) => return v.getValue()
        case _ => throw Exception("missing string field: " + key)
    }
}

public func getOptStr(o: JsonObject, key: String): Option<String> {
    match (o.get(key)) {
        case Some(v: JsonString) => return Some(v.getValue())
        case _ => return None
    }
}

public func getInt(o: JsonObject, key: String): Int64 {
    match (o.get(key)) {
        case Some(v: JsonInt) => return v.getValue()
        case _ => throw Exception("missing int field: " + key)
    }
}

public func getStrArray(o: JsonObject, key: String): ArrayList<String> {
    let result = ArrayList<String>()
    match (o.get(key)) {
        case Some(arr: JsonArray) =>
            for (item in arr) {
                match (item) {
                    case s: JsonString => result.add(s.getValue())
                    case _ => ()
                }
            }
        case _ => ()
    }
    return result
}

/* =========================================================================
 * 三、传输层：按行分帧（TODO(M0)：按实际 stdx.net API 校准）
 * =========================================================================
 * 约定：
 *   readLine  —— 读到 '\n' 为止，返回不含换行的字符串；对端关闭返回 None；
 *                超过 MAX_LINE_SIZE 时抛出异常，由调用方按 1006 处理。
 *   writeLine —— 写出 text + "\n"，成功返回 true。
 * ========================================================================= */

public func writeLine(sock: TcpSocket, text: String): Bool {
    try {
        sock.write((text + "\n").toArray())
        return true
    } catch (e: Exception) {
        return false
    }
}

public func readLine(sock: TcpSocket): Option<String> {
    let buf = ArrayList<UInt8>()
    while (true) {
        let chunk = try {
            sock.read(1)              /* TODO(M0): 按实际 API 读取 1 字节 */
        } catch (e: Exception) {
            return None               /* 对端关闭或读失败 */
        }
        if (chunk.size == 0) { return None }
        let b = chunk[0]
        if (b == 0x0A) {              /* '\n' */
            return Some(String.fromUtf8(buf.toArray()))
        }
        if (b == 0x0D) { continue }   /* 忽略 '\r'，兼容 CRLF */
        buf.add(b)
        if (buf.size > MAX_LINE_SIZE) {
            throw Exception("line too long")
        }
    }
}

/* =========================================================================
 * 四、时间与通用应答构造
 * ========================================================================= */

public func nowSeconds(): Int64 {
    return DateTime.now().toUnixTimeStamp().toSeconds()
}

public func okMsg(action: String): JsonObject {
    let o = newMsg(MSG_OK)
    putStr(o, "action", action)
    return o
}

public func errMsg(code: Int64, message: String): JsonObject {
    let o = newMsg(MSG_ERROR)
    putInt(o, "code", code)
    putStr(o, "message", message)
    return o
}

public func systemMsg(text: String): JsonObject {
    let o = newMsg(MSG_SYSTEM)
    putStr(o, "text", text)
    putInt(o, "ts", nowSeconds())
    return o
}

public func chatMsg(scope: String, room: String, from: String, to: String, text: String): JsonObject {
    let o = newMsg(MSG_MESSAGE)
    putStr(o, "scope", scope)
    if (!room.isEmpty()) { putStr(o, "room", room) }
    putStr(o, "from", from)
    if (!to.isEmpty()) { putStr(o, "to", to) }
    putStr(o, "text", text)
    putInt(o, "ts", nowSeconds())
    return o
}
