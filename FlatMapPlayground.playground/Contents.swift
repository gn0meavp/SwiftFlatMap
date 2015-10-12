import UIKit

enum Result<T> {
    case Value(T)
    case Error(String)
    
    func map<U>(f: T -> U) -> Result<U> {
        switch self {
        case let .Value(value):
            return Result<U>.Value(f(value))
        case let .Error(error):
            return Result<U>.Error(error)
        }
    }
    
    func flatMap<U>(f: T -> Result<U>) -> Result<U> {
        return Result.flatten(map(f))
    }
    
    static func flatten<T>(result: Result<Result<T>>) -> Result<T> {
        switch result {
        case let .Value(innerResult):
            return innerResult
        case let .Error(error):
            return Result<T>.Error(error)
        }
    }
}

func divideByTwo_map(value: Int) -> Int {
    if value > 2 {
        return value / 2
    }
    
    return -1   // to simulate .Error
}

func divideByTwo_flatMap(value: Int) -> Result<Int> {
    if value > 2 {
        return Result.Value(value / 2)
    }
    return Result<Int>.Error("error")
}

let result1 = Result<Int>.Value(10).map(divideByTwo_map).map(divideByTwo_map).map(divideByTwo_map).map(divideByTwo_map)
let result2 = Result<Int>.Value(10).flatMap(divideByTwo_flatMap).flatMap(divideByTwo_flatMap).flatMap(divideByTwo_flatMap)