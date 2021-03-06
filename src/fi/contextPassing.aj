
package org.fi;


import org.fi.*;

import java.io.*;
import java.net.*;
import java.nio.channels.*;
import java.nio.*;
import java.util.*;

import java.net.InetSocketAddress;
import java.lang.Thread;
import java.lang.StackTraceElement;


import org.aspectj.lang.Signature; // include this for Signature, etc!
import org.aspectj.lang.JoinPoint;
import org.aspectj.lang.reflect.SourceLocation;


// import org.apache.hadoop.net.SocketOutputStream;


// *********************************************************************
// remember lowest precedence is executed first
// *********************************************************************
aspect precedenceAspect {
  declare precedence
    :

  // OLD
  // contextOrigin, contextPassing, contextPassingNonDirect,
  // profilingHooks, fiHooks, frogHooks;


  /*frogHooks, */ fiHooks, /*profilingHooks, */
    contextWrapper, contextPassingNonDirect, contextPassing, contextOrigin;

}

// context debug
aspect CD {
  public static boolean debug = false;
  //public static boolean debug = true;
}

// *********************************************************************
// this aspect should define the context origin. One example is when
// a File is created with new File (String).  That string must be
// put in the context, and then hooked into the newly created object
// *********************************************************************
aspect contextOrigin {

  // context from new File(..)
  File around() : call(File.new(..)) && !within(org.fi.*) {
    File f = proceed();
    f.setContext(new Context(f.getAbsolutePath()));
    if (CD.debug) {
			System.out.format("# Context creation [%s]\n",f.context);
		}
    return f;
  }

  // context from new RandomAccessFile(name)
//  RandomAccessFile around(File f, String m)
 //   : !within(org.fi.*) &&
  //  call (RandomAccessFile+.new(File,String)) && args(f,m) {
  //  RandomAccessFile r = proceed(f,m);
    //File f = new File(s); // help from File to get the absolute path
   // r.context = new Context(f.getAbsolutePath());
   // if (CD.debug) System.out.format("# Context creation RAF [%s]\n",r.context);
    //return r;
  //}
	
	// context from new RandomAccessFile(name)
  //after()
   // : !within(org.fi.*) &&
    //initialization (RandomAccessFile+.new(..)){
		//System.out.format("# Context creation RAF(1) \n");
		//FMJoinPoint fjp = new FMJoinPoint(thisJoinPoint);
		//System.out.println(">>> " +fjp);
		//return proceed();
	//}
	
	
//#################################################################
//Jungmin added
//#################################################################	
	
 Object around(String n, String m, int i)
    : !within(org.fi.*) &&
    call (RandomAccessFile+.new(String,String,int)) && args(n,m,i) {
    Object temp = proceed(n,m,i);
    File f = new File(n); // help from File to get the absolute path
    RandomAccessFile r = (RandomAccessFile) temp;
	  r.context = new Context(f.getAbsolutePath());
    if (CD.debug) {
		System.out.format("Context creation RAF(2) [%s]\n", r.context);
		FMJoinPoint fjp = new FMJoinPoint(thisJoinPoint);
		System.out.println(">>> " +fjp);
		}
		return r;
 }
 
 	///////////////////////////////////////////////////////////////////
	///////////////////////////////////////////////////////////////////
	//Jin-Su made changes here
	///////////////////////////////////////////////////////////////////
	
	//Making ipfiles to identify cassandra nodes
	//every starting node will call this function to get which ip they need to connect to.
	//so catch this and make ip history function.
	
	Object around() : (within(org.apache.cassandra.thrift.CassandraDaemon) && (call (* org.apache.cassandra.utils.FBUtilities.*(..)) || call (* org.apache.cassandra.config.DatabaseDescriptor.*(..)))) {
		Object tmp = proceed();
		if(tmp instanceof InetAddress) {
			InetAddress iaddr = (InetAddress) tmp;
			//System.out.println("&&& Calling from ip-creating helper");
			Util.addIpHistory(iaddr);
		}
		return tmp;
	} 
	
	
	//Context creation for OutputStream
  //happens inside OutboundTcpConnection
  
  //Context creation for outgoingSocket
  Object around(InetAddress ep, int eport, InetAddress lp, int lport) : (call (Socket.new(InetAddress, int, InetAddress, int)) && !within(org.fi.*) && args(ep, eport, lp, lport) ) {
  	if (CD.debug) {
  		System.out.println("&&&Outbound socket.new cut");
  	}
  	Util.addIpHistory(lp);
  	//Util.addIpHistory(ep);
  	Object tmp = proceed(ep, eport, lp, lport);
  	if (tmp instanceof Socket) {
			Socket s = (Socket) tmp;
			
			if(s.getLocalPort() != 0) {
			s.context = new Context(s.getLocalPort());

      if (CD.debug) {
        System.out.format("# Context creation Socket [%d]   \n", s.context.getPort());
      }
      
			//port has binded add it in the history
			if (CD.debug) {
        System.out.format("# Adding socket history (a) ... [%d] %s \n",
                          s.getLocalPort(), Util.getNodeId());
      }
      Util.addSocketHistory(s);
      return (Object) s;
			}
			return tmp;
  	}
  	return tmp;
  }
	
	//I don't need it?  
  //Context creation for incomingSocket
  /*
  Object around(Socket s) : (call (org.apache.cassandra.net.IncomingTcpConnection.new(Socket)) && !within(org.fi.*) && args(s) ) {
  	System.out.println("&&&Incoming socket.new cut");
		InetAddress lp = null;
  	Util.addIpHistory(lp);
  	Util.addIpHistory(ep);
  	Object tmp = proceed(s);
  	if (tmp instanceof Socket) {
			Socket s = (Socket) tmp;
			
			if(s.getLocalPort() != 0) {
			s.context = new Context(s.getLocalPort());

      if (CD.debug) {
        System.out.format("# Context creation Socket [%d]   \n", s.context.getPort());
      }
      
			//port has binded add it in the history
			if (CD.debug) {
        System.out.format("# Adding socket history (a) ... [%d] %s \n",
                          s.getLocalPort(), Util.getNodeId());
      }
      Util.addSocketHistory(s);
      return (Object) s;
			}
			return tmp;
  	}
  	return tmp;
  }
  */
  
  OutputStream around(Socket s) : (call (OutputStream Socket.*(..)) && !within(org.fi.*) && target(s)) {
  Object tmp = proceed(s);
  OutputStream os = (OutputStream) tmp;
  /*
  InetAddress l_iaddr = s.getLocalAddress();
  if(CD.testing) {
  System.out.println("&&&OutputStream Local InetAddress = " + l_iaddr.getHostAddress());
  }
  if(s.getLocalPort() != 0 
  		&& !l_iaddr.isAnyLocalAddress()) {
  		//Context(InetAddress, ..)
  		//does InetAddress.getHostAddress() to set ip context.
  		s.context = new Context(l_iaddr, s.getLocalPort());
  		if(CD.testing) {
  		System.out.println("&&&OutputStream Context creation .. " + s.toString());
  		}
  		Util.addIpHistory(l_iaddr);
    } else {
    	System.out.println("###Socket port is 0. =(");
    }
  */
  InetAddress r_iaddr = s.getInetAddress();
  String net_ctx = Util.getNetIOContext(r_iaddr, s.getPort());
  if(net_ctx != null) {
  	if(CD.debug) {
  		System.out.println("\n&&&NetContext ... " + net_ctx);
  	}
  	os.setContext(new Context(net_ctx));
  }
  
  return os;
  }
  
  //For Context Creation for InputStream
  //happens inside IncomingTcpConnection
  
  InputStream around(Socket s) : (call (InputStream Socket.*(..)) && !within(org.fi.*) && target(s)) {
  Object tmp = proceed(s);
  InputStream is = (InputStream) tmp;
  /*
  InetAddress l_iaddr = s.getLocalAddress();
  if(CD.testing) {
  	System.out.println("&&&InputStream Local InetAddress = " + l_iaddr.getHostAddress());
  }
  if(s.getLocalPort() != 0 
  		&& !l_iaddr.isAnyLocalAddress()) {
  		s.context = new Context(l_iaddr, s.getLocalPort());
  		if(CD.testing) {
 				System.out.println("&&&InputStream Context creation .. " + s.toString());
 			}
  		Util.addIpHistory(l_iaddr);
    } else {
    	System.out.println("###Socket port is 0. =(");
    }
  */
  InetAddress r_iaddr = s.getInetAddress();
  String net_ctx = Util.getNetIOContext(r_iaddr, s.getPort());
  if(net_ctx != null) {
  	if(CD.debug) {
  		System.out.println("\n&&&NetContext ... " + net_ctx);
  	}
  	is.setContext(new Context(net_ctx));
  }
  return is;
 }

 
 


  // *****************************************************************

  // for channel stuffs, we need to do this because connect is not
  // always blocking operation. and SocketChannel.getPort()
  // always be a *successful* connection to remote.
  // Thus, if we want to find out if sc.X() fails, at this point
  // we don't know what's the remote address is.
  Object around(SocketChannel sc, SocketAddress sa)
    : (call (boolean SocketChannel.connect(SocketAddress)) &&
       target(sc) &&
       args(sa) && !within(org.fi.*)) {
    if (sa instanceof InetSocketAddress) {
      InetSocketAddress isa = (InetSocketAddress)sa;
      sc.context = new Context(isa.getPort());

      if (CD.debug)
        System.out.format("# Context creation SC [%d]   \n", sc.context.getPort());

    }

    Object tmp = proceed(sc, sa);

    // check if sc is successfully connected or not
    Socket s = sc.socket();
    if (s.getLocalPort() != 0) {
      if (CD.debug) {
        System.out.format("# Adding socket history (a) ... [%d] %s \n",
                          s.getLocalPort(), Util.getNodeId());
      }
      Util.addSocketHistory(s);
    }


    return tmp;
  }


  // this is where we get the local port,
  // sc.finishConnect() in SocketIOWithTimeout.java
  after(SocketChannel sc) returning
    : (call (boolean SocketChannel.finishConnect()) &&
       target(sc) && !within(org.fi.*) ) {

    // everytime the call is successful, we'll get the local port
    // now let's add this local port to our history
    Socket s = sc.socket();

    if (CD.debug) {
      System.out.format("# Adding socket history (b) ... [%d] %s \n",
                        s.getLocalPort(), Util.getNodeId());
    }

    Util.addSocketHistory(s);
  }


  // *****************************************************************

  // creating context for output stream from channel
  // for any creation of new OutputStream+(...Socket...)
  // then we want to create context on behalf of this context.
  // If I don't understand the port Id ("Unknown-port") this means
  // this port is a created port on the fly ... let's check the socketHistory
  // MAKE sure build.xml involves the correct files from core/net/*.java
  Object around(Socket s, long to)
    : (call (OutputStream+.new(Socket,long)) && args(s, to)
       && !within(org.fi.*)
       ) {
    Object tmp = proceed(s, to);
    OutputStream os = (OutputStream)tmp;
    String ctx = Util.getNetIOContextFromPort(s.getPort());
    if (ctx != null) {
      os.context = new Context(ctx);

      if (CD.debug) {
        System.out.format
          ("# OutStream Context creation from network .. [%s] \n", ctx);
      }

    }
    return tmp;
  }

  Object around(Socket s, long to)
    : (call (InputStream+.new(Socket,long)) && args(s, to) && !within(org.fi.*) ) {
    Object tmp = proceed(s, to);
    ClassWC cwc = (ClassWC) tmp;
    String ctx = Util.getNetIOContextFromPort(s.getPort());
    if (ctx != null) {
      cwc.setContext(new Context(ctx));

      if (CD.debug) {
        System.out.format
          ("# InStream Context creation from network .. [%s] \n", ctx);
      }
    }
    else {
      Util.WARNING(" unknown port: " + s.getPort());
    }
    return tmp;
  }

  // getNetIOContextFromPort(port);


}



// *********************************************************************
// this aspect is saying that if we instantiate an object from another
// object that already has context, then that context should be cloned
// to the new object
// *********************************************************************
aspect contextPassing {

  // boolean debug = false;
  boolean debug = true;

  // *********************************************
  // XXX these are somehow hack ways to pass context
  // in my small test files the general way below works fine
  // but not when I try to run this in HDFS
  // I think for FOS, FIS, RAF,
  // it does not work when
  // 1) we use (..) as constructor arguments .. so we must
  //    specify the exact arg types, it works.
  // 2) we must convert the classes to ClassWC ourselves
  // 3) cannot use after(), must use around()
  // e.g. FIS fis = new FIS (f)  or RAF raf = new RAF (f, ..)
  // *********************************************
  Object around(File f)
    : !within(org.fi.*) && call (FileInputStream.new(File)) && args(f)  {
    Context ctx =
      (f.getContext() != null) ? f.getContext() :
      new Context(f.getAbsolutePath());
    return passContext(thisJoinPoint, (ClassWC)(proceed(f)), ctx);
  }

  Object around(File f)
    : !within(org.fi.*) && call (FileOutputStream.new(File)) && args(f) {
    Context ctx =
      (f.getContext() != null) ? f.getContext() :
      new Context(f.getAbsolutePath());
    return passContext(thisJoinPoint, (ClassWC)(proceed(f)), ctx);
  }

  Object around(File f, String s)
    : !within(org.fi.*) && call (RandomAccessFile.new(File,String)) && args(f,s) {
    Context ctx =
      (f.getContext() != null) ? f.getContext() :
      new Context(f.getAbsolutePath());
    return passContext(thisJoinPoint, (ClassWC)(proceed(f,s)), ctx);
  }
	
	  //Object around(File f, String s, int i)
    //: !within(org.fi.*) && call (RandomAccessFile.new(File,String,int)) && args(f,s,i) {
    //Context ctx =
      //(f.getContext() != null) ? f.getContext() :
      //new Context(f.getAbsolutePath());
    //return passContext(thisJoinPoint, (ClassWC)(proceed(f,s,i)), ctx);
  //}
	
	//Object around() : call(* RandomAccessFile+.writeLong(..)) && !within(org.fi.*) {
		//Object temp = proceed();
		//System.out.println("");
    //System.out.println("  >>>>> " + thisJoinPoint.toString() + thisJoinPoint.getSourceLocation());
    //System.out.println("");
		
		//Object[] args = thisJoinPoint.getArgs();
    //for (int i = 0; i < args.length; i++) {
      //if (args[i] instanceof ClassWC) {
        //ClassWC c = (ClassWC)(args[i]);
	
				//if (c.getContext() != null) {
					//((ClassWC)temp).setContext(c.getContext());
					//System.out.println("Context passing .." + c.getContext().getTargetIO() + thisJoinPoint.getSourceLocation());
				//}
			//break;
      //}
    //}
    //return temp;
  //}
	
	

  // *********************************************
  // These are other ways (besides instantiations) where context
  // is created.
  // *********************************************
  Object around(ClassWC f)
    : !within(org.fi.*) &&
    call (FileChannel RandomAccessFile.getChannel()) && target(f) {
    return passContext(thisJoinPoint, (ClassWC)(proceed(f)), f.getContext());
  }


  // *********************************************
  // this is a general way for passing context
  // *********************************************


	//TODO : Original, change it back to this.
  // find instantiations where contexts should be passed
  //pointcut classWCNew()
  //  : call (ClassWC+.new(..,ClassWC+,..)) &&
  //  !within(org.fi.*);
  //NEW==================
  //Jin-Su Making changes
  pointcut classWCNew()
    : call (ClassWC+.new(..,ClassWC+,..)) &&
    !within(org.fi.*) && !withincode(* org.apache.cassandra.net.IncomingTcpConnection.run()) 
    && !withincode(* org.apache.cassandra.db.ReadVerbHandler.doVerb(..));

  // pass the context (this is a generic advice)
  Object around() : classWCNew () {

    // I go on with the instantiation
    Object temp = proceed();

    // find any arg that is an instance of ClassWC
    // if found, then pass that context
    Object[] args = thisJoinPoint.getArgs();
    for (int i = 0; i < args.length; i++) {
      if (args[i] instanceof ClassWC) {
        ClassWC a = (ClassWC)(args[i]);
        passContext(thisJoinPoint, (ClassWC)(temp), a.getContext());
        break;
      }
    }
    return temp;
  }


  // *********************************************
  // common function to pass context
  // *********************************************
  ClassWC passContext(JoinPoint jp, ClassWC t, Context c) {
    if (!Util.assertCtx(jp, c)) return t;
    t.setContext(c);
    if (CD.debug) {
      System.out.println("# Context passing direct ..." + c + jp.getSourceLocation());
    }
    return t;
  }


}



// *********************************************************************
// this is context passing for inextensible classes (hence non direct)
// perthis is undesired because we're adding something local (e.g.
// map(fd,context) to something global (the map), and we always map.put
// all the time, so the memory will increase all the time
// *********************************************************************
aspect contextPassingNonDirect perthis(blockedContext(ClassWC)) {

  public Object ctxKey;
  public Context ctxValue;

  // these are the pointcuts for context that is not passable
  // you define the "final" class that is returned
  pointcut blockedContext(ClassWC cwc)
    : !within(org.fi.*) && call (FileDescriptor ClassWC+.*(..)) && target(cwc);

  //
  Object around(ClassWC cwc) : blockedContext(cwc) {
    Object obj = proceed(cwc);
    ctxKey = obj;
    ctxValue = cwc.getContext();
    if (ctxValue == null)
      Util.FATAL(thisJoinPoint, "non-direct context passing is null");
    if (CD.debug) {
      System.out.println("# Context saved for non-direct ...");
    }
    return obj;
  }


  // this is what we should do under the control flow,
  // so this is another pointcut
  pointcut timeToPassContext(FileDescriptor tempArg)
    : !within(org.fi.*) && call (ClassWC+.new(..,FileDescriptor,..)) && args(tempArg);

  // time to pass the context, get the context from the map
  Object around(Object tempArg) : timeToPassContext(tempArg) {
    if (ctxValue == null)
      Util.FATAL(thisJoinPoint, "non-direct context is null");
    if (ctxKey != tempArg)
      Util.FATAL(thisJoinPoint, "try to pass non-direct context to multiple classes");

    Object temp = proceed(tempArg);
    ((ClassWC)temp).setContext(ctxValue);
    if (CD.debug) {
      System.out.println("# Context passing non-direct ...");
    }
    return temp;
  }

}

// *********************************************************************
// this wraps BufferedOutputStream, so that we can get the buffer
// when we flush dataoutputstream and reverse engineer the buffer
// *********************************************************************
aspect contextWrapper {

  // intercept new BOS(..) with new BOSW(..)
  Object around(OutputStream os) 
    : ((!within(org.fi.*) && args(os)) &&
       (call (BufferedOutputStream.new(OutputStream)))
       ) {
    BufferedOutputStreamWrapper bosw = new BufferedOutputStreamWrapper(os);
    bosw.context = os.context; // context passing done explicitly for wrapper
    BufferedOutputStream bos = bosw;
    return (Object)bos;
  }
  
  // intercept new BOS(..) with new BOSW(..)
  Object around(OutputStream os, int sz) 
    : ((!within(org.fi.*) && args(os,sz)) &&
       (call (BufferedOutputStream.new(OutputStream,int)))
       ) {
    BufferedOutputStreamWrapper bosw = new BufferedOutputStreamWrapper(os, sz);
    bosw.context = os.context; // context passing done explicitly for wrapper
    BufferedOutputStream bos = bosw;
    return (Object)bos;
  }

  // intercept new DOS
  Object around(OutputStream os)
    : ((!within(org.fi.*) && args(os)) &&
       (call (DataOutputStream.new(OutputStream)))
       ) {
    Object obj = proceed(os);
    DataOutputStream dos = (DataOutputStream)obj;
    // context passing has been done
    if (os instanceof BufferedOutputStreamWrapper) {
      if (os.getContext() != null) {
	if (os.getContext() == dos.getContext()) {
	  Context ctx = dos.getContext();
	  ctx.setExtraContext(os);	      
	}
	else {
	  Util.FATAL("why OS's context is not equal to DOS's context");
	}
      }
    }
    return obj;
  }


}
