//
//  The MIT License (MIT)
//
//  Copyright (c) 2016 Srdan Rasic (@srdanrasic)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

// MARK: - StreamEventType

/// Represents a stream event.
public protocol StreamEventType: EventType {
}

// MARK: - StreamEvent

/// Represents a stream event.
public enum StreamEvent<T>: StreamEventType {

  /// The type of elements generated by the stream.
  public typealias Element = T

  /// Contains element.
  case Next(T)

  /// Stream is completed.
  case Completed

  /// Create new `.Next` event.
  public static func next(element: T) -> StreamEvent<Element> {
    return .Next(element)
  }

  /// Create new `.Completed` event.
  public static func completed() -> StreamEvent<Element> {
    return .Completed
  }

  /// Extract an element from a non-terminal (`.Next`) event.
  public var element: Element? {
    switch self {
    case .Next(let element):
      return element
    default:
      return nil
    }
  }

  /// Does the event mark failure of a stream? Always `False` for `StreamEvent`.
  public var isFailure: Bool {
    return false
  }

  /// Does the event mark completion of a stream? `True` if event is `.Completion`.
  public var isCompletion: Bool {
    switch self {
    case .Next:
      return false
    case .Completed:
      return true
    }
  }
}

// MARK: - StreamEventType Extensions

public extension StreamEventType {

  public var unbox: StreamEvent<Element> {
    if let element = element {
      return StreamEvent.Next(element)
    } else {
      return StreamEvent.Completed
    }
  }

  public func map<U>(transform: Element -> U) -> StreamEvent<U> {
    switch self.unbox {
    case .Next(let value):
      return .Next(transform(value))
    case .Completed:
      return .Completed
    }
  }
}

// MARK: - StreamType

/// Represents a stream over generic Element type.
public protocol StreamType: _StreamType {

  /// The type of elements generated by the stream.
  associatedtype Element

  /// Underlying raw stream. Stream is just a wrapper over `RawStream` that
  /// operates on events of `StreamEvent` type.
  var rawStream: RawStream<StreamEvent<Element>> { get }

  /// Register an observer that will receive events from the stream. Registering
  /// an observer starts the stream. Disposing the returned disposable can
  /// be used to cancel (stop) the stream.
  @warn_unused_result
  func observe(observer: StreamEvent<Element> -> Void) -> Disposable
}

public extension StreamType {

  /// Transform the stream by transforming underlying raw stream.
  public func lift<U>(transform: RawStream<StreamEvent<Element>> -> RawStream<StreamEvent<U>>) -> Stream<U> {
    return Stream<U> { observer in
      return transform(self.rawStream).observe(observer.observer)
    }
  }

  /// Register an observer that will receive events from the stream. Registering
  /// an observer starts the stream. Disposing the returned disposable can
  /// be used to cancel (stop) the stream.
  @warn_unused_result
  public func observe(observer: StreamEvent<Element> -> Void) -> Disposable {
    return rawStream.observe(observer)
  }
}

// MARK: - Stream

/// Represents a stream over generic Element type.
/// Well-formed streams conform to the grammar: `Next* Completed`.
public struct Stream<T>: StreamType {

  /// The type of elements generated by the stream.
  public typealias Element = T

  public typealias Event = StreamEvent<T>

  /// Underlying raw stream. Stream is just a wrapper over `RawStream` that
  /// operates on events of `StreamEvent` type.
  public let rawStream: RawStream<StreamEvent<T>>

  /// Create a new stream from a raw stream.
  public init(rawStream: RawStream<StreamEvent<T>>) {
    self.rawStream = rawStream
  }

  /// Create a new stream using a producer.
  public init(producer: Observer<Event> -> Disposable) {
    rawStream = RawStream(producer: producer)
  }
}

// MARK: - Extensions

// MARK: Creating a stream

public extension Stream {

  /// Create a stream that emits given element and then completes.
  @warn_unused_result
  public static func just(element: Element) -> Stream<Element> {
    return Stream { observer in
      observer.next(element)
      observer.completed()
      return SimpleDisposable()
    }
  }

  /// Create a stream that emits given sequence of elements and then completes.
  @warn_unused_result
  public static func sequence<S: SequenceType where S.Generator.Element == Element>(sequence: S) -> Stream<Element> {
    return Stream { observer in
      sequence.forEach(observer.next)
      observer.completed()
      return SimpleDisposable()
    }
  }

  /// Create a stream that completes without emitting any elements.
  @warn_unused_result
  public static func completed() -> Stream<Element> {
    return Stream { observer in
      observer.completed()
      return SimpleDisposable()
    }
  }

  /// Create an stream that never completes.
  @warn_unused_result
  public static func never() -> Stream<Element> {
    return Stream { observer in
      return SimpleDisposable()
    }
  }

  /// Create a stream that emits an integer every `interval` time on a given queue.
  @warn_unused_result
  public static func interval(interval: TimeValue, queue: Queue) -> Stream<Int> {
    return Stream<Int>(rawStream: RawStream.interval(interval, queue: queue))
  }

  /// Create a stream that emits given element after `time` time on a given queue.
  @warn_unused_result
  public static func timer(element: Element, time: TimeValue, queue: Queue) -> Stream<Element> {
    return Stream<Element>(rawStream: RawStream.timer(element, time: time, queue: queue))
  }
}

// MARK: Transforming stream

public extension StreamType {

  /// Batch the elements into arrays of given size.
  @warn_unused_result
  public func buffer(size: Int) -> Stream<[Element]> {
    return Stream { observer in
      var buffer: [Element] = []
      return self.observe { event in
        switch event {
        case .Next(let element):
          buffer.append(element)
          if buffer.count == size {
            observer.next(buffer)
            buffer.removeAll()
          }
        case .Completed:
          observer.completed()
        }
      }
    }
  }

  /// Map each event into a stream and then flatten those streams using
  /// the given flattening strategy.
  @warn_unused_result
  public func flatMap<U: StreamType>(strategy: FlatMapStrategy, transform: Element -> U) -> Stream<U.Element> {
    let transform: Element -> Stream<U.Element> = { transform($0).toStream() }
    switch strategy {
    case .Latest:
      return map(transform).switchToLatest()
    case .Merge:
      return map(transform).merge()
    case .Concat:
      return map(transform).concat()
    }
  }

  /// Map each event into an operation and then flatten those operation using
  /// the given flattening strategy.
  @warn_unused_result
  public func flatMap<U: OperationType>(strategy: FlatMapStrategy, transform: Element -> U) -> Operation<U.Element, U.Error> {
    let transform: Element -> Operation<U.Element, U.Error> = { transform($0).toOperation() }
    switch strategy {
    case .Latest:
      return map(transform).switchToLatest()
    case .Merge:
      return map(transform).merge()
    case .Concat:
      return map(transform).concat()
    }
  }

  /// Transform each element by applying `transform` on it.
  @warn_unused_result
  public func map<U>(transform: Element -> U) -> Stream<U> {
    return lift { stream in
      stream.map { event in
        return event.map(transform)
      }
    }
  }

  /// Apply `combine` to each element starting with `initial` and emit each
  /// intermediate result. This differs from `reduce` which emits only final result.
  @warn_unused_result
  public func scan<U>(initial: U, _ combine: (U, Element) -> U) -> Stream<U> {
    return lift { stream in
      return stream.scan(.Next(initial)) { memo, new in
        switch new {
        case .Next(let element):
          return .Next(combine(memo.element!, element))
        case .Completed:
          return .Completed
        }
      }
    }
  }

  /// Convert the stream to an operation.
  @warn_unused_result
  public func toOperation<E: ErrorType>() -> Operation<Element, E> {
    return Operation { observer in
      return self.observe { event in
        switch event {
        case .Next(let element):
          observer.next(element)
        case .Completed:
          observer.completed()
        }
      }
    }
  }

  /// Convert the stream to a concrete stream.
  @warn_unused_result
  public func toStream() -> Stream<Element> {
    return Stream(rawStream: self.rawStream)
  }

  /// Batch each `size` elements into another stream.
  @warn_unused_result
  public func window(size: Int) -> Stream<Stream<Element>> {
    return buffer(size).map { Stream.sequence($0) }
  }
}

// MARK: Filtration

extension StreamType {

  /// Emit an element only if `interval` time passes without emitting another element.
  @warn_unused_result
  public func debounce(interval: TimeValue, on queue: Queue) -> Stream<Element> {
    return lift { $0.debounce(interval, on: queue) }
  }

  /// Emit first element and then all elements that are not equal to their predecessor(s).
  @warn_unused_result
  public func distinct(areDistinct: (Element, Element) -> Bool) -> Stream<Element> {
    return lift { $0.distinct(areDistinct) }
  }

  /// Emit only element at given index if such element is produced.
  @warn_unused_result
  public func elementAt(index: Int) -> Stream<Element> {
    return lift { $0.elementAt(index) }
  }

  /// Emit only elements that pass `include` test.
  @warn_unused_result
  public func filter(include: Element -> Bool) -> Stream<Element> {
    return lift { $0.filter { $0.element.flatMap(include) ?? true } }
  }

  /// Emit only the first element generated by the stream and then complete.
  @warn_unused_result
  public func first() -> Stream<Element> {
    return lift { $0.first() }
  }

  /// Ignore all elements (just propagate terminal events).
  @warn_unused_result
  public func ignoreElements() -> Stream<Element> {
    return lift { $0.ignoreElements() }
  }

  /// Emit only last element generated by the stream and then complete.
  @warn_unused_result
  public func last() -> Stream<Element> {
    return lift { $0.last() }
  }

  /// Periodically sample the stream and emit latest element from each interval.
  @warn_unused_result
  public func sample(interval: TimeValue, on queue: Queue) -> Stream<Element> {
    return lift { $0.sample(interval, on: queue) }
  }

  /// Suppress first `count` elements generated by the stream.
  @warn_unused_result
  public func skip(count: Int) -> Stream<Element> {
    return lift { $0.skip(count) }
  }

  /// Suppress last `count` elements generated by the stream.
  @warn_unused_result
  public func skipLast(count: Int) -> Stream<Element> {
    return lift { $0.skipLast(count) }
  }

  /// Emit only first `count` elements of the stream and then complete.
  @warn_unused_result
  public func take(count: Int) -> Stream<Element> {
    return lift { $0.take(count) }
  }

  /// Emit only last `count` elements of the stream and then complete.
  @warn_unused_result
  public func takeLast(count: Int) -> Stream<Element> {
    return lift { $0.takeLast(count) }
  }

  /// Throttle the stream to emit at most one element per given `seconds` interval.
  @warn_unused_result
  public func throttle(seconds: TimeValue) -> Stream<Element> {
    return lift { $0.throttle(seconds) }
  }
}

extension StreamType where Element: Equatable {

  /// Emit first element and then all elements that are not equal to their predecessor(s).
  @warn_unused_result
  public func distinct() -> Stream<Element> {
    return lift { $0.distinct() }
  }
}

public extension StreamType where Element: OptionalType, Element.Wrapped: Equatable {

  /// Emit first element and then all elements that are not equal to their predecessor(s).
  @warn_unused_result
  public func distinct() -> Stream<Element> {
    return lift { $0.distinct() }
  }
}

public extension StreamType where Element: OptionalType {

  /// Suppress all `nil`-elements.
  @warn_unused_result
  public func ignoreNil() -> Stream<Element.Wrapped> {
    return Stream { observer in
      return self.observe { event in
        switch event {
        case .Next(let element):
          if let element = element._unbox {
            observer.next(element)
          }
        case .Completed:
          observer.completed()
        }
      }
    }
  }
}

// MARK: Combination

extension StreamType {

  /// Emit a pair of latest elements from each stream. Starts when both streams
  /// emit at least one element, and emits `.Next` when either stream generates an element.
  @warn_unused_result
  public func combineLatestWith<S: StreamType>(other: S) -> Stream<(Element, S.Element)> {
    return lift {
      return $0.combineLatestWith(other.toStream()) { myLatestElement, my, theirLatestElement, their in
        switch (my, their) {
        case (.Completed, .Completed):
          return StreamEvent.Completed
        case (.Next(let myElement), .Next(let theirElement)):
          return StreamEvent.Next(myElement, theirElement)
        case (.Next(let myElement), .Completed):
          if let theirLatestElement = theirLatestElement {
            return StreamEvent.Next(myElement, theirLatestElement)
          } else {
            return nil
          }
        case (.Completed, .Next(let theirElement)):
          if let myLatestElement = myLatestElement {
            return StreamEvent.Next(myLatestElement, theirElement)
          } else {
            return nil
          }
        }
      }
    }
  }

  /// Merge emissions from both source and `other` into one stream.
  @warn_unused_result
  public func mergeWith<S: StreamType where S.Element == Element>(other: S) -> Stream<Element> {
    return lift { $0.mergeWith(other.rawStream) }
  }

  /// Prepend given element to the operation emission.
  @warn_unused_result
  public func startWith(element: Element) -> Stream<Element> {
    return lift { $0.startWith(.Next(element)) }
  }

  /// Emit elements from source and `other` in pairs. This differs from `combineLatestWith` in
  /// that pairs are produced from elements at same positions.
  @warn_unused_result
  public func zipWith<S: StreamType>(other: S) -> Stream<(Element, S.Element)> {
    return lift {
      return $0.zipWith(other.toStream()) { my, their in
        switch (my, their) {
        case (.Next(let myElement), .Next(let theirElement)):
          return StreamEvent.Next(myElement, theirElement)
        case (_, .Completed):
          return StreamEvent.Completed
        case (.Completed, _):
          return StreamEvent.Completed
        default:
          fatalError("This will never execute: Swift compiler cannot infer switch completeness.")
        }
      }
    }
  }
}

//  MARK: Utilities

extension StreamType {

  /// Set the execution context in which to execute the stream (i.e. in which to run
  /// the stream's producer).
  @warn_unused_result
  public func executeIn(context: ExecutionContext) -> Stream<Element> {
    return lift { $0.executeIn(context) }
  }

  /// Delay stream events for `interval` time.
  @warn_unused_result
  public func delay(interval: TimeValue, on queue: Queue) -> Stream<Element> {
    return lift { $0.delay(interval, on: queue) }
  }

  /// Do side-effect upon various events.
  @warn_unused_result
  public func doOn(next next: (Element -> ())? = nil,
                        start: (() -> Void)? = nil,
                        completed: (() -> Void)? = nil,
                        disposed: (() -> ())? = nil,
                        terminated: (() -> ())? = nil) -> Stream<Element> {
    return Stream { observer in
      start?()
      let disposable = self.observe { event in
        switch event {
        case .Next(let value):
          next?(value)
        case .Completed:
          completed?()
          terminated?()
        }
        observer.observer(event)
      }
      return BlockDisposable {
        disposable.dispose()
        disposed?()
        terminated?()
      }
    }
  }

  /// Use `doOn` to log various events.
  @warn_unused_result
  public func debug(id: String = "Untitled Stream") -> Stream<Element> {
    return doOn(next: { element in
        print("\(id): Next(\(element))")
      }, start: {
        print("\(id): Start")
      }, completed: {
        print("\(id): Completed")
      }, disposed: {
        print("\(id): Disposed")
      })
  }

  /// Set the execution context in which to dispatch events (i.e. in which to run observers).
  @warn_unused_result
  public func observeIn(context: ExecutionContext) -> Stream<Element> {
    return lift { $0.observeIn(context) }
  }

  /// Supress non-terminal events while last event generated on other stream is `false`.
  @warn_unused_result
  public func pausable<S: _StreamType where S.Event.Element == Bool>(by other: S) -> Stream<Element> {
    return lift { $0.pausable(other) }
  }
}

// MARK: Conditional, Boolean and Aggregational

extension StreamType {

  /// Propagate event only from a stream that starts emitting first.
  @warn_unused_result
  public func ambWith<S: StreamType where S.Element == Element>(other: S) -> Stream<Element> {
    return lift { $0.ambWith(other.rawStream) }
  }

  /// Collect all elements into an array and emit just that array.
  @warn_unused_result
  public func collect() -> Stream<[Element]> {
    return reduce([], { memo, new in memo + [new] })
  }

  /// First emit events from source and then from `other` stream.
  @warn_unused_result
  public func concatWith<S: StreamType where S.Element == Element>(other: S) -> Stream<Element> {
    return lift { stream in
      stream.concatWith(other.rawStream)
    }
  }

  /// Emit default element is the stream completes without emitting any element.
  @warn_unused_result
  public func defaultIfEmpty(element: Element) -> Stream<Element> {
    return lift { $0.defaultIfEmpty(element) }
  }

  /// Reduce elements to a single element by applying given function on each emission.
  @warn_unused_result
  public func reduce<U>(initial: U, _ combine: (U, Element) -> U) -> Stream<U> {
    return Stream<U> { observer in
      observer.next(initial)
      return self.scan(initial, combine).observe(observer.observer)
    }.last()
  }

  /// Par each element with its predecessor. First element is paired with `nil`.
  @warn_unused_result
  public func zipPrevious() -> Stream<(Element?, Element)> {
    return Stream { observer in
      var previous: Element? = nil
      return self.observe { event in
        switch event {
        case .Next(let element):
          observer.next((previous, element))
          previous = element
        case .Completed:
          observer.completed()
        }
      }
    }
  }
}

// MARK: Streams that emit other streams

public extension StreamType where Element: StreamType, Element.Event: StreamEventType {

  public typealias InnerElement = Element.Event.Element

  /// Flatten the stream by observing all inner streams and propagate elements from each one as they come.
  @warn_unused_result
  public func merge() -> Stream<InnerElement> {
    return lift { stream in
      return stream.merge({ $0.unbox }, propagateErrorEvent: { _, _ in })
    }
  }

  /// Flatten the stream by observing and propagating emissions only from the latest inner stream.
  @warn_unused_result
  public func switchToLatest() -> Stream<InnerElement> {
    return lift { stream in
      return stream.switchToLatest({ $0.unbox }, propagateErrorEvent: { _, _ in })
    }
  }

  /// Flatten the stream by sequentially observing inner streams in order in
  /// which they arrive, starting next observation only after the previous one completes.
  @warn_unused_result
  public func concat() -> Stream<InnerElement> {
    return lift { stream in
      return stream.concat({ $0.unbox }, propagateErrorEvent: { _, _ in })
    }
  }
}

// MARK: Streams that emit operations

public extension StreamType where Element: OperationType, Element.Event: OperationEventType {
  public typealias InnerOperationElement = Element.Event.Element
  public typealias InnerOperationError = Element.Event.Error

  /// Flatten the stream by observing all inner operation and propagate elements from each one as they come.
  @warn_unused_result
  public func merge() -> Operation<InnerOperationElement, InnerOperationError> {
    return self.toOperation().merge()
  }

  /// Flatten the stream by observing and propagating emissions only from the latest inner operation, cancelling previous one when new one starts.
  @warn_unused_result
  public func switchToLatest() -> Operation<InnerOperationElement, InnerOperationError> {
    return self.toOperation().switchToLatest()
  }

  /// Flatten the stream by sequentially observing inner operations in order in
  /// which they arrive, starting next observation only after the previous one completes.
  @warn_unused_result
  public func concat() -> Operation<InnerOperationElement, InnerOperationError> {
    return self.toOperation().switchToLatest()
  }
}

// MARK: Connectable

extension StreamType {

  /// Ensure that all observers see the same sequence of elements. Connectable.
  @warn_unused_result
  public func replay(limit: Int = Int.max) -> ConnectableStream<Element> {
    return ConnectableStream(rawConnectableStream: rawStream.replay(limit))
  }

  /// Convert the stream to a connectable stream.
  @warn_unused_result
  public func publish() -> ConnectableStream<Element> {
    return ConnectableStream(rawConnectableStream: rawStream.publish())
  }

  /// Ensure that all observers see the same sequence of elements. 
  /// Shorthand for `replay(limit).refCount()`.
  @warn_unused_result
  public func shareReplay(limit: Int = Int.max) -> Stream<Element> {
    return replay(limit).refCount()
  }
}

// MARK: Functions

/// Combine multiple streams into one. See `mergeWith` for more info.
@warn_unused_result
public func combineLatest
  <A: StreamType,
   B: StreamType>
  (a: A, _ b: B) -> Stream<(A.Element, B.Element)> {
  return a.combineLatestWith(b)
}

/// Combine multiple operations into one. See `mergeWith` for more info.
@warn_unused_result
public func combineLatest
  <A: StreamType,
   B: StreamType,
   C: StreamType>
  (a: A, _ b: B, _ c: C) -> Stream<(A.Element, B.Element, C.Element)> {
  return combineLatest(a, b).combineLatestWith(c).map { ($0.0, $0.1, $1) }
}

/// Combine multiple operations into one. See `mergeWith` for more info.
@warn_unused_result
public func combineLatest
  <A: StreamType,
   B: StreamType,
   C: StreamType,
   D: StreamType>
  (a: A, _ b: B, _ c: C, _ d: D) -> Stream<(A.Element, B.Element, C.Element, D.Element)> {
  return combineLatest(a, b, c).combineLatestWith(d).map { ($0.0, $0.1, $0.2, $1) }
}

/// Combine multiple operations into one. See `mergeWith` for more info.
@warn_unused_result
public func combineLatest
  <A: StreamType,
   B: StreamType,
   C: StreamType,
   D: StreamType,
   E: StreamType>
  (a: A, _ b: B, _ c: C, _ d: D, _ e: E) -> Stream<(A.Element, B.Element, C.Element, D.Element, E.Element)> {
  return combineLatest(a, b, c, d).combineLatestWith(e).map { ($0.0, $0.1, $0.2, $0.3, $1) }
}

/// Combine multiple operations into one. See `mergeWith` for more info.
@warn_unused_result
public func combineLatest
  <A: StreamType,
   B: StreamType,
   C: StreamType,
   D: StreamType,
   E: StreamType,
   F: StreamType>
  (a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) -> Stream<(A.Element, B.Element, C.Element, D.Element, E.Element, F.Element)> {
  return combineLatest(a, b, c, d, e).combineLatestWith(f).map { ($0.0, $0.1, $0.2, $0.3, $0.4, $1) }
}

/// Zip multiple operations into one. See `zipWith` for more info.
@warn_unused_result
public func zip
  <A: StreamType,
   B: StreamType>
  (a: A, _ b: B) -> Stream<(A.Element, B.Element)> {
  return a.zipWith(b)
}

/// Zip multiple operations into one. See `zipWith` for more info.
@warn_unused_result
public func zip
  <A: StreamType,
   B: StreamType,
   C: StreamType>
  (a: A, _ b: B, _ c: C) -> Stream<(A.Element, B.Element, C.Element)> {
  return zip(a, b).zipWith(c).map { ($0.0, $0.1, $1) }
}

/// Zip multiple operations into one. See `zipWith` for more info.
@warn_unused_result
public func zip
  <A: StreamType,
   B: StreamType,
   C: StreamType,
   D: StreamType>
  (a: A, _ b: B, _ c: C, _ d: D) -> Stream<(A.Element, B.Element, C.Element, D.Element)> {
  return zip(a, b, c).zipWith(d).map { ($0.0, $0.1, $0.2, $1) }
}

/// Zip multiple operations into one. See `zipWith` for more info.
@warn_unused_result
public func zip
  <A: StreamType,
   B: StreamType,
   C: StreamType,
   D: StreamType,
   E: StreamType>
  (a: A, _ b: B, _ c: C, _ d: D, _ e: E) -> Stream<(A.Element, B.Element, C.Element, D.Element, E.Element)> {
  return zip(a, b, c, d).zipWith(e).map { ($0.0, $0.1, $0.2, $0.3, $1) }
}

/// Zip multiple operations into one. See `zipWith` for more info.
@warn_unused_result
public func zip
  <A: StreamType,
   B: StreamType,
   C: StreamType,
   D: StreamType,
   E: StreamType,
   F: StreamType>
  (a: A, _ b: B, _ c: C, _ d: D, _ e: E, _ f: F) -> Stream<(A.Element, B.Element, C.Element, D.Element, E.Element, F.Element)> {
  return zip(a, b, c, d, e).zipWith(f).map { ($0.0, $0.1, $0.2, $0.3, $0.4, $1) }
}

// MARK: - ConnectableStream

/// Represents a stream that is started by calling `connect` on it.
public class ConnectableStream<T>: StreamType {
  public typealias Event = StreamEvent<T>

  private let rawConnectableStream: RawConnectableStream<RawStream<Event>>

  public var rawStream: RawStream<StreamEvent<T>> {
    return rawConnectableStream.toRawStream()
  }

  private init(rawConnectableStream: RawConnectableStream<RawStream<Event>>) {
    self.rawConnectableStream = rawConnectableStream
  }

  /// Register an observer that will receive events from the stream.
  /// Note that the events will not be generated until `connect` is called.
  @warn_unused_result
  public func observe(observer: Event -> Void) -> Disposable {
    return rawConnectableStream.observe(observer)
  }

  /// Start the stream.
  public func connect() -> Disposable {
    return rawConnectableStream.connect()
  }
}

// MARK: - ConnectableStream Extensions

public extension ConnectableStream {

  /// Convert connectable stream into the ordinary one by calling `connect`
  /// on first subscription and calling dispose when number of observers goes down to zero.
  @warn_unused_result
  public func refCount() -> Stream<T> {
    return Stream(rawStream: self.rawConnectableStream.refCount())
  }
}

// MARK: - PushStream

/// Represents a stream that can push events to registered observers at will.
public class PushStream<T>: StreamType, SubjectType {
  private let subject = PublishSubject<StreamEvent<T>>()
  private let disposeBag = DisposeBag()

  public var rawStream: RawStream<StreamEvent<T>> {
    return subject.toRawStream()
  }

  public init() {
  }

  /// Send event to all registered observers.
  public func on(event: StreamEvent<T>) {
    subject.on(event)
  }
}

// MARK: - BindableType

/// Bindable is like an observer, but knows to manage the subscription by itself.
public protocol BindableType {
  associatedtype Element

  /// Returns an observer that can be used to dispatch events to the receiver.
  /// Can accept a disposable that will be disposed on receiver's deinit.
  func observer(disconnectDisposable: Disposable) -> (StreamEvent<Element> -> ())
}

extension StreamType {

  /// Establish a one-way binding between the source and the bindable's observer
  /// and return a disposable that can cancel binding.
  public func bindTo<B: BindableType where B.Element == Element>(bindable: B) -> Disposable {
    let disposable = SerialDisposable(otherDisposable: nil)
    let observer = bindable.observer(disposable)
    disposable.otherDisposable = observe(observer)
    return disposable
  }

  /// Establish a one-way binding between the source and the bindable's observer
  /// and return a disposable that can cancel binding.
  public func bindTo<B: BindableType where B.Element: OptionalType, B.Element.Wrapped == Element>(bindable: B) -> Disposable {
    let disposable = SerialDisposable(otherDisposable: nil)
    let observer = bindable.observer(disposable)
    disposable.otherDisposable = observe { event in
      switch event {
      case .Next(let element):
        observer(.Next(B.Element(element)))
      case .Completed:
        observer(.Completed)
        disposable.dispose()
      }
    }
    return disposable
  }
}

extension PushStream: BindableType {

  /// Returns an observer that can be used to dispatch events to the receiver.
  /// Can accept a disposable that will be disposed on receiver's deinit.
  public func observer(disconnectDisposable: Disposable) -> StreamEvent<T> -> () {
    disposeBag.addDisposable(disconnectDisposable)
    return { [weak self] in self?.on($0) }
  }
}
