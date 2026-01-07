# Example Cap'n Proto Schema for Neuro-OS IPC
#
# This demonstrates the Cap'n Proto schema format used for
# inter-process communication in Neuro-OS.

@0x85150b117366d14b;  # Unique file ID

# Basic message types
struct Message {
  id @0 :UInt64;
  timestamp @1 :UInt64;
  sender @2 :ProcessId;
  
  union {
    notification @3 :Notification;
    request @4 :Request;
    response @5 :Response;
  }
}

struct ProcessId {
  pid @0 :UInt32;
  namespace @1 :Text;
}

# Notification messages (one-way)
struct Notification {
  eventType @0 :EventType;
  data @1 :Data;
  
  enum EventType {
    shutdown @0;
    restart @1;
    configChanged @2;
    resourceLimit @3;
  }
}

# Request-response pattern
struct Request {
  requestId @0 :UInt64;
  method @1 :Text;
  arguments @2 :List(Argument);
}

struct Response {
  requestId @0 :UInt64;
  
  union {
    success @1 :Data;
    error @2 :Error;
  }
}

struct Argument {
  name @0 :Text;
  value @1 :Data;
}

# Generic data container
struct Data {
  union {
    null @0 :Void;
    bool @1 :Bool;
    int @2 :Int64;
    uint @3 :UInt64;
    float @4 :Float64;
    text @5 :Text;
    bytes @6 :Data;
    list @7 :List(Data);
    struct @8 :List(KeyValue);
  }
}

struct KeyValue {
  key @0 :Text;
  value @1 :Data;
}

struct Error {
  code @0 :UInt32;
  message @1 :Text;
  details @2 :Data;
}

# Service interface example
interface Service {
  call @0 (request :Request) -> (response :Response);
  subscribe @1 (eventType :Notification.EventType) -> (stream :EventStream);
}

interface EventStream {
  nextEvent @0 () -> (notification :Notification);
  cancel @1 () -> ();
}
