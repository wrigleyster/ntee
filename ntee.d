
import std.conv : to;
import std.stdio : write, writeln, writefln;
import std.socket : Socket, TcpSocket, InternetAddress, SocketOptionLevel,
       SocketOption, SocketSet, SocketShutdown;
import std.array: split;

class Config{
    bool   verbose;
    ushort in_port;
    ushort out_port;
    string out_domain;
}
char[1024] buffer;

void main(string[] args)
{
    Config c = parseArgs(args);
    serve(c);
}

void serve(Config c){
    auto listener = new TcpSocket();
    assert(listener.isAlive);
    listener.blocking = true;
    listener.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
    listener.bind(new InternetAddress(c.in_port));
    listener.listen(10);

    if(c.verbose)
        writefln(":listening on %d", c.in_port);
    auto sock = listener.accept();
    auto echo = new TcpSocket(new InternetAddress(c.out_domain, c.out_port));
    auto sockSet = new SocketSet(10);
    scope(exit){
        echo.shutdown(SocketShutdown.BOTH);
        echo.close();
        listener.shutdown(SocketShutdown.BOTH);
        listener.close();
        sock.shutdown(SocketShutdown.BOTH);
        sock.close();
    }


    while(sock.isAlive && echo.isAlive){
        sockSet.add(sock);
        sockSet.add(echo);
        Socket.select(sockSet, null, null);
        if(sockSet.isSet(sock) && !pipe(sock, echo)){
            sock.close();
            sock = listener.accept();
        }
        if(sockSet.isSet(echo) && !pipe(echo, sock)){
            echo.close();
        }
        sockSet.reset();
    }

}

bool pipe(Socket sin, Socket sout){
    auto msg = read(sin);
    if(!msg.length){
        return false;
    }
    forward(sout, msg);
    write(msg);
    return true;
}


char[] read(Socket sock){
    auto written = sock.receive(buffer[]);
    return buffer[0 .. written];
}
void forward(Socket sock, char[] msg){
    sock.send(msg);
}

Config parseArgs(string[] args){
    
    assert(args.length > 1);
    auto c = new Config();
    for(int i=1; i<args.length; i++)
    {
        if(args[i] == "-l"){
            c.in_port = to!ushort(args[++i]);
            continue;
        }
        if(args[i] == "-v"){
            c.verbose = true;
            continue;
        }
        auto parts = args[i].split(":");
        assert(parts.length == 2, "host badly defined");
        c.out_domain = parts[0];
        c.out_port = to!ushort(parts[1]);
    }
    return c;
}
