import UIKit
import XCPlayground

XCPSetExecutionShouldContinueIndefinitely(true)

enum Result<T> {
    case Value(T)
    case Error(NSError)
    
    // Functor is any type that defines how map applies to it.
    func map<U>(f: T -> U) -> Result<U> {
        switch self {
        case let .Value(value):
            return Result<U>.Value(f(value))
        case let .Error(error):
            return Result<U>.Error(error)
        }
    }
    
    // Applicative is a type where even functions may be wrapped in a context
    func apply<U>(f: Result<(T -> U)>) -> Result<U> {
        switch f {
            case .Value(let someF):
                return self.map(someF)
            case let .Error(error):
                return Result<U>.Error(error)
        }
    }
    
    // Monads apply a function that returns a wrapped value to a wrapped value
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
    
    func flatten() -> T? {
        switch self {
        case let .Value(value):
            return value
        case .Error(_):
            return nil
        }
    }
}

infix operator <^> { associativity left }
func <^><T, U>(f: T -> U, a: Result<T>) -> Result<U> {
    return a.map(f)
}

infix operator <*> { associativity left }
func <*><T, U>(f: Result<(T -> U)>, a: Result<T>) -> Result<U> {
    return a.apply(f)
}

infix operator >>- { associativity left }
func >>-<T, U>(a: Result<T>, f: T -> Result<U>) -> Result<U> {
    return a.flatMap(f)
}

/*:
### Sample #1 (simple)
*/

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
    return Result<Int>.Error(NSError(domain: "error", code: 0, userInfo: nil))
}

// Let's see what is the difference between map and flatMap?
Result.Value(10).map(divideByTwo_map).map(divideByTwo_map).map(divideByTwo_map).map(divideByTwo_map)
Result.Value(10).flatMap(divideByTwo_flatMap).flatMap(divideByTwo_flatMap).flatMap(divideByTwo_flatMap)

// Let's do the same with infix operator. Just because we can :)
divideByTwo_map <^> (divideByTwo_map <^> (divideByTwo_map <^> Result.Value(10)))
Result.Value(10) >>- divideByTwo_flatMap >>- divideByTwo_flatMap >>- divideByTwo_flatMap

// Let's try apply
let wrappedFunc = Result.Value(divideByTwo_map)
Result.Value(10).apply(wrappedFunc).apply(wrappedFunc).apply(wrappedFunc)
wrappedFunc <*> (wrappedFunc <*> (wrappedFunc <*> Result.Value(10)))

/*:
### Sample #2 (complex)
*/
// Echo JSON: Returns a customized JSON object that you can define through a REST-style URL (see http://www.jsontest.com for documentation)
let request = NSURLRequest(URL: NSURL(string: "http://echo.jsontest.com/type/\(rand()%4)/temperature/\((rand()%50-20))")!)
let session = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())

session.dataTaskWithRequest(request) { (data, response, error) -> Void in
    let result = checkTaskError(data, response: response, error: error) >>- (getHTTPURLResponse) >>- (checkStatusCode) >>- (checkDataNotEmpty) >>- (parseData) >>- (createWeatherObject)
    switch result {
    case let .Value(value) :
        print("\(value)")
    case let .Error(error) :
        print(error)
    }
}.resume()


///

enum WeatherType: Int {
    case Rainy = 0
    case Stormy
    case Sunny
    case Cloudy
}

struct Weather {
    let type: WeatherType
    let temperature: Float
}

extension String {
    init(stringInterpolationSegment weather: Weather) {
        self = "There's no bad weather, just bad clothing. It's \(weather.temperature)ºC today, \(weather.type)."
    }
    
    init(stringInterpolationSegment type: WeatherType) {
        switch type {
        case .Rainy:
            self = "rainy"
        case .Stormy:
            self = "stormy"
        case .Sunny:
            self = "sunny"
        case .Cloudy:
            self = "cloudy"
        }
    }
}

let errorDomain = "com.test"

enum WeatherError: Int {
    case UnknownError = 0
    case WrongStatusCode
    case NoData
    case IncorrectStructure
}

enum Errors: ErrorType {
    case MyError
    case YourError
}


// sample of logic in bunch of functions

func checkTaskError(data: NSData?, response: NSURLResponse?, error: NSError?) -> Result<(NSData?, NSURLResponse?)> {
    if let error = error {
        return Result<(NSData?, NSURLResponse?)>.Error(error)
    }
    
    return Result.Value((data, response))
}

func getHTTPURLResponse(data: NSData?, response: NSURLResponse?) -> Result<(NSData?, NSHTTPURLResponse)> {
    if let response = response as? NSHTTPURLResponse {
        return Result.Value(data, response)
    }
    
    return Result<(NSData?, NSHTTPURLResponse)>.Error(Errors.MyError) //(NSError(domain: errorDomain, code: WeatherError.UnknownError.rawValue, userInfo: nil))
}

func checkStatusCode(data: NSData?, response: NSHTTPURLResponse) -> Result<NSData?> {
    if response.statusCode == 200 {
        return Result.Value(data)
    }
    
    return Result<NSData?>.Error(NSError(domain: errorDomain, code: WeatherError.WrongStatusCode.rawValue, userInfo: ["statusCode": response.statusCode]))
}

func checkDataNotEmpty(data: NSData?) -> Result<NSData> {
    if let data = data {
        return Result.Value(data)
    }
    
    return Result<NSData>.Error(NSError(domain: errorDomain, code: WeatherError.NoData.rawValue, userInfo: nil))
}

func parseData(data: NSData) -> Result<NSDictionary> {
    do {
        let parsed = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments) as! NSDictionary
        return Result.Value(parsed)
    }
    catch let error as NSError {
        return Result<NSDictionary>.Error(error)
    }
}

func createWeatherObject(parsed: NSDictionary) -> Result<Weather> {
    guard let typeString = parsed["type"] as? String,
        let temperatureString = parsed["temperature"] as? String else {
            return Result.Error(NSError(domain: errorDomain, code: WeatherError.IncorrectStructure.rawValue, userInfo: nil))
    }
    
    guard let typeInt = Int(typeString),
        let temperatureFloat = Float(temperatureString) else {
            return Result.Error(NSError(domain: errorDomain, code: WeatherError.IncorrectStructure.rawValue, userInfo: nil))
    }
    
    guard let weatherType = WeatherType(rawValue: typeInt) else {
        return Result.Error(NSError(domain: errorDomain, code: WeatherError.IncorrectStructure.rawValue, userInfo: nil))
    }
    
    let weather = Weather(type: weatherType, temperature: temperatureFloat)
    
    return Result.Value(weather)
}

