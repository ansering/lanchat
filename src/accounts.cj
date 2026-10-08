package lanchat

import std.collection.*

/* 持久化记录；算法和参数随记录保存，以便日后验证旧账号。 */
public class AccountRecord {
    public let username: String
    public var enabled: Bool
    public let salt: String
    public let verifier: String
    public let kdf: String
    public let iterations: Int64

    public init(username: String, enabled: Bool, salt: String,
        verifier: String, kdf: String, iterations: Int64) {
        this.username = username
        this.enabled = enabled
        this.salt = salt
        this.verifier = verifier
        this.kdf = kdf
        this.iterations = iterations
    }
}

public class AccountSummary {
    public let username: String
    public let enabled: Bool

    public init(username: String, enabled: Bool) {
        this.username = username
        this.enabled = enabled
    }
}

/* 管理命令在停服后使用；运行中的服务端只调用 load 和 verify。 */
public class AccountStore {
    private let path: String
    private let records = HashMap<String, AccountRecord>()

    public init(path: String) { this.path = path }

    /* 文件不存在、损坏或读取失败时必须报错；只有 add 可创建新文件。 */
    public func load(): Unit { todo("AccountStore.load") }

    /* add/reset 负责安全随机盐、密码派生及原子写入。 */
    public func add(username: String, password: String): Unit { todo("AccountStore.add") }
    public func reset(username: String, password: String): Unit { todo("AccountStore.reset") }
    public func disable(username: String): Unit { todo("AccountStore.disable") }
    public func list(): ArrayList<AccountSummary> { throw Exception("TODO: not implemented: AccountStore.list") }

    /* 不向调用方区分用户名不存在、停用和口令错误。 */
    public func verify(username: String, password: String): Bool {
        throw Exception("TODO: not implemented: AccountStore.verify")
    }
}
