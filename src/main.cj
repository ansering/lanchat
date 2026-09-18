package lanchat

/*
 * ============================================================================
 * main.cj —— 程序入口【框架】
 * ----------------------------------------------------------------------------
 * 仅负责参数解析与模式分派，具体行为由 Server / Client 实现。
 *
 * 用法：
 *   lanchat server [port]              以服务端模式启动（默认 9000）
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
            Server(parsePort(args, 2)).run()
            0
        case "client" =>
            if (args.size < 3) {
                println("错误：缺少主机地址")
                printUsage()
                return 1
            }
            Client(args[2], parsePort(args, 3)).run()
            0
        case _ =>
            printUsage()
            1
    }
}

func parsePort(args: Array<String>, index: Int64): UInt16 {
    if (args.size <= index) {
        return DEFAULT_PORT
    }
    /* TODO(M1): 解析失败时提示并回退默认端口 */
    match (UInt16.parse(args[index])) {
        case Some(p) => return p
        case None => return DEFAULT_PORT
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
