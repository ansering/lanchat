package lanchat

/*
 * ============================================================================
 * main.cj —— 程序入口
 * ----------------------------------------------------------------------------
 * 用法：
 *   lanchat server [port]              以服务端模式启动（默认端口 9000）
 *   lanchat client <host> [port]       以客户端模式连接主机
 * ============================================================================
 */

public let DEFAULT_PORT: UInt16 = 9000

public func main(args: Array<String>): Int64 {
    if (args.size < 2) {
        printUsage()
        return 1
    }

    match (args[1]) {
        case "server" =>
            let port = parsePort(args, 2, DEFAULT_PORT)
            Server(port).run()
            0
        case "client" =>
            if (args.size < 3) {
                println("错误：缺少主机地址")
                printUsage()
                return 1
            }
            let host = args[2]
            let port = parsePort(args, 3, DEFAULT_PORT)
            Client(host, port).run()
            0
        case _ =>
            printUsage()
            1
    }
}

func parsePort(args: Array<String>, index: Int64, fallback: UInt16): UInt16 {
    if (args.size <= index) {
        return fallback
    }
    match (UInt16.parse(args[index])) {
        case Some(p) => return p
        case None => return fallback
    }
}

func printUsage(): Unit {
    println("LAN Chat v1.0")
    println("用法:")
    println("  lanchat server [port]             以服务端模式启动（默认 ${DEFAULT_PORT}）")
    println("  lanchat client <host> [port]      连接主机")
    println("示例:")
    println("  lanchat server")
    println("  lanchat client 192.168.1.10 9000")
}
