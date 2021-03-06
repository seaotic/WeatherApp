//
//  Backend.swift
//  WeatherApp
//
//  Created by Noah Riley McCampbell (Student) on 3/3/22.
//

import Foundation
import CoreLocation
import SwiftUI


var locationManager:CLLocationManager?

//Location Services Delegeate and handler
class locationManagerC : NSObject, ObservableObject, CLLocationManagerDelegate{
    @Published var auth : CLAuthorizationStatus
    @Published var lat = 0.0
    @Published var lon = 0.0
    @Published var didGetLocation = false
    @Published var whereAmi = "in the Void"
    @Published var regioncode = ""
    private let locationManager:CLLocationManager
    
    //Initalizes and starts location services on start of app
    override init(){
        locationManager = CLLocationManager()
        auth = locationManager.authorizationStatus
        
        super.init()
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
        
    }
    //Ask for permission to use location
    func askForPerms(){
        locationManager.requestWhenInUseAuthorization()
    }
    //Set authentication status
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        auth = locationManager.authorizationStatus
        switch auth{
        case .authorizedWhenInUse:
            hasCLAuth = true
        case .denied:
            hasCLAuth = false
        case .notDetermined:
            hasCLAuth = false
        case .restricted:
            hasCLAuth = false
        default:
            hasCLAuth = false
        }
    }
    //Set latitude and longitude through grabbed locations(Activates when it has detected a location or you have moved).
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let locations = locations.last {
            lat = locations.coordinate.latitude
            lon = locations.coordinate.longitude
            CLGeocoder().reverseGeocodeLocation(locations) { f ,_ in
                self.whereAmi = f?.first?.locality ?? "Void"
                self.regioncode = f?.first?.administrativeArea ?? ""
            }
            gotLocationData = true
        }
    }
}

/*
var weatherDictionary: NSDictionary?
var todayDict: NSDictionary?
*/

//Todays WeatherData
struct TodayData:Hashable{
    var temp:String
    var forecast:String
    var shortforecast:String
    var weatherIconURL:String
    var name:String
}
struct HourData:Hashable{
    var temp:Int
    var shortforecast:String
    var weatherIconURL:String
    var startTime:String
}
//OLD CODE
/*
func getWeatherData(urls: String, completion: @escaping (_ json: Any?, _ error: Error?)->()) {
    let session = URLSession.shared
    let WeatherURL = URL(string: urls)
    let sessionData = session.dataTask(with: WeatherURL!){
        (data: Data?, response: URLResponse?, error: Error?) in
        if let error = error{
            print("Something went wrong in the HTTP Request: \(error)")
            completion(nil, error)
        }
        do{
            if let data = data {
                let dataSring = String(data: data, encoding: String.Encoding.utf8)
                if let jsonObj = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? NSDictionary{
                    print(jsonObj)
                    completion(jsonObj, error)
                }
            }
        } catch {
            print("JSON PARSING ERROR: \(error)")
        }
    }
    sessionData.resume()
}
 */
//enum for the state the app is currently in done(Finished getting data and can load view), loading(Currently grabbing and parsing data from API), fail(error occurred somewhere).
enum stateLoad {
    case done
    case loading
    case fail(Error)
}
//Main Weather Grabbing and Formatting Operations
class WeatherModel: NSObject, ObservableObject{
    @Published var weatherDictionary: NSDictionary?
    @Published var todayDict: NSDictionary?
    @Published var tDat = TodayData.init(temp: "Undefined", forecast: "Undefined", shortforecast: "Undefined", weatherIconURL: "Undefined", name:"undefined")
    //Aysynchronusly takes and url and returns the data from it in a dictionary.
    func GrabDataMain(urls: String) async throws -> NSDictionary{
        print("got main")
        //Starts a session that can be used to get data
        let session = URLSession.shared
        var data:Data?
        if let url = URL(string: urls){
            (data, _) = try await session.data(from: url)
            print(urls)
        }
        //returns data
        return try (JSONSerialization.jsonObject(with: data!, options: .fragmentsAllowed) as? NSDictionary)!
        
    }
    //GRABS MAIN WEATHER DATA JSON
    func setUpMain(lati: Float, long: Float, completion: @escaping (Result<NSDictionary, Error>) async -> Void) async{
        Task{
            do{
                let weatherDat = try await GrabDataMain(urls: "https://api.weather.gov/points/\(lati),\(long)") as? NSDictionary
                self.weatherDictionary = weatherDat?["properties"] as! NSDictionary
                await completion(.success(weatherDat?["properties"] as! NSDictionary))
                
            } catch{
                await completion(.failure(error))
            }
        }
    }
    //Grabs and formats todays current data
    func setUpToday(MainData: NSDictionary,completion: @escaping (Result<NSDictionary, Error>) async ->  Void) async{
        Task{
        do{
            print("got 2")
            let todayDat = try await GrabDataMain(urls: MainData["forecast"] as! String)
            print(MainData["forecast"])
            print(todayDat)
            formattedDataB = todayDat["properties"] as! NSDictionary
            await completion(.success(todayDat["properties"] as! NSDictionary))
        }catch{
            await completion(.failure(error))
        }
    }
}
    func setUpHourly(MainData: NSDictionary,completion: @escaping (Result<NSDictionary, Error>) async ->  Void) async{
        Task{
        do{
            print("got 2")
            let hourlyDat = try await GrabDataMain(urls: MainData["forecastHourly"] as! String)
            print(MainData["forecastHourly"])
            formattedDataB = hourlyDat["properties"] as! NSDictionary
            await completion(.success(hourlyDat["properties"] as! NSDictionary))
        }catch{
            await completion(.failure(error))
        }
    }
}
    //This goes through the data gathered and gets data from each "key" which is essentially just a variable name.
    func formatTodayData(todayData: NSDictionary?){
        if let periods = todayData?["periods"] {
            self.todayDict = (periods as! NSArray)[0] as? NSDictionary
            //Set Temp Var
            self.tDat.temp = String(todayDict?["temperature"] as! Int)
            //Set short Forecast
            self.tDat.shortforecast = todayDict?["shortForecast"] as! String
            //Set Detailed Forecast
            self.tDat.forecast = todayDict?["detailedForecast"] as! String
            print(self.tDat.forecast)
            //Set Icon Image URL
            self.tDat.weatherIconURL = todayDict?["icon"] as! String
            //print out temperature debug test.
            
        } else{
            //If parsing fails.
            print("Cannot convert to NSArray?")
        }
    }
    func formatWeekData(todayData:NSDictionary?){
        if let periods = todayData?["periods"]{
            for day in periods as! NSArray {
                let NS = day as? NSDictionary
                let dayData = TodayData.init(temp: String(NS?["temperature"] as! Int), forecast: NS?["detailedForecast"] as! String, shortforecast: NS?["shortForecast"] as! String, weatherIconURL: NS?["icon"] as! String, name: NS?["name"] as! String)
                Week.append(dayData)
            }
        }
    }
    func formatHourlyData(hourlyData:NSDictionary?){
        if let hours = hourlyData?["periods"]{
            for hour in hours as! NSArray{
                let NS = hour as? NSDictionary
                var hourData = HourData.init(temp: NS?["temperature"] as! Int, shortforecast: NS?["shortForecast"] as! String, weatherIconURL: NS?["icon"] as! String, startTime: NS?["startTime"] as! String)
                //Parsing out the Time for the hourly forecast
                let strArr = hourData.startTime.components(separatedBy: CharacterSet.decimalDigits.inverted)
                hourData.startTime = strArr[3]
                
                //Code for making time into actual normal AM PM time stamp
                if Int(hourData.startTime)! > 12{
                    hourData.startTime = "\(String(Int(hourData.startTime)! - 12)) PM"
                }else if Int(hourData.startTime)! < 12 && Int(hourData.startTime)! > 0{
                    hourData.startTime = "\(String(Int(hourData.startTime)!)) AM"
                }else if Int(hourData.startTime) == 0{
                    hourData.startTime = "12 AM"
                }else{
                    hourData.startTime = "\(String(Int(hourData.startTime)!)) PM"
                }
                
                if Int(hourData.startTime) == 0{
                   hourData.startTime = "12 AM"
                }
                Hours.append(hourData)
                
            }
            //removed the other hours entries for the other days of the week, app only show the next 48 hours in the hourly menu
            for i in 1...132 {
                Hours.removeLast()
            }
        }
    }
}

//Backend initialization of all classes and variables needed for the data to be pulled on start
var weatherModel = WeatherModel()
var locationM = locationManagerC()
var formattedDataB:NSDictionary?
var Week:[TodayData] = []
var Hours:[HourData] = []
var pulledTodayDat = false
var hasCLAuth = false
var gotLocationData = false

/*
func setUpMain() {
    
        getWeatherData(urls: "https://api.weather.gov/points/39.899226,-77.680552"){ json, error in
            if let error = error {
                print(error)
            }
            else if let json = json{
                print(json)
                //Get Todays Forecast JSON URL
                weatherDictionary = (json as! NSDictionary)["properties"] as? NSDictionary
                setUpToday()
            }
        }
     
}
 */
//Grab TODAY'S Forecast JSON File and parse
/*
func setUpToday() {
        getWeatherData(urls: weatherDictionary?["forecast"] as! String){ json, error in
            if let error = error {
                print(error)
            }
            else if let jsonF = json{
                weatherDictionary = (jsonF as! NSDictionary)["properties"] as! NSDictionary
                if let periods = weatherDictionary?["periods"] {
                    todayDict = (periods as! NSArray)[0] as? NSDictionary
                    //Set Temp Var
                    tDat.temp = String(todayDict?["temperature"] as! Int)
                    //Set short Forecast
                    tDat.shortforecast = todayDict?["shortForecast"] as! String
                    //Set Detailed Forecast
                    tDat.forecast = todayDict?["detailedForecast"] as! String
                    //Set Icon Image URL
                    tDat.weatherIconURL = todayDict?["icon"] as! String
                    //print out temperature debug test.
                    print(String(todayDict?["temperature"] as! Int))
                    
                } else{
                    //If parsing fails.
                    print("Cannot convert to NSArray?")
                }
            }
        }
}
*/



