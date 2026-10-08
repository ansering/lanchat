package lanchat

import std.convert.*

/* 程序入口只负责参数和模式分派。args[0] 是第一个用户参数。 */
public let DEFAULT_PORT: UInt16 = 9000
public let ACCOUNT_FILE = "data/accounts.json"

main(args: Array<String>): Int64 {
    if (args.size == 0) {
        printUsage()
        return 1
    }

    match (args[0]) {
        case "server" =>
            if (args.size > 2) { printUsage(); return 1 }
            Server(parsePort(args, 1), AccountStore(ACCOUNT_FILE)).run()
            0
        case "client" =>
            if (args.size < 2 || args.size > 3) { printUsage(); return 1 }
            Client(args[1], parsePort(args, 2)).run()
            0
        case "account" => accountMain(args)
        case _ =>
            printUsage()
            1
    }
}

/* 账号命令只在服务端本机、停服后执行；口令不放进命令行。 */
func accountMain(args: Array<String>): Int64 {
    if (args.size < 2) { printUsage(); return 1 }
    let accounts = AccountStore(ACCOUNT_FILE)
    match (args[1]) {
        case "list" =>
            if (args.size != 2) { printUsage(); return 1 }
            accounts.load()
            for (item in accounts.list()) {
                if (item.enabled) {
                    println("${item.username} enabled")
                } else {
                    println("${item.username} disabled")
                }
            }
            0
        case "add" =>
            if (args.size != 3) { printUsage(); return 1 }
            accounts.add(args[2], readPassword())
            0
        case "disable" =>
            if (args.size != 3) { printUsage(); return 1 }
            accounts.load()
            accounts.disable(args[2])
            0
        case "reset" =>
            if (args.size != 3) { printUsage(); return 1 }
            accounts.load()
            accounts.reset(args[2], readPassword())
            0
        case _ =>
            printUsage()
            1
    }
}

/* M0 确认当前 SDK 的无回显终端输入 API 后实现。 */
func readPassword(): String {
    throw Exception("TODO: readPassword")
}

func parsePort(args: Array<String>, index: Int64): UInt16 {
    if (args.size <= index) { return DEFAULT_PORT }
    match (UInt16.tryParse(args[index])) {
        case Some(port) =>
            if (port == 0) { throw Exception("端口必须在 1–65535 之间") }
            port
        case None => throw Exception("无效端口：${args[index]}")
    }
}

func printUsage(): Unit {
    println("LAN Chat 用法:")
    println("  lanchat server [port]")
    println("  lanchat client <server-ip> [port]")
    println("  lanchat account list")
    println("  lanchat account add|disable|reset <username>")
}
