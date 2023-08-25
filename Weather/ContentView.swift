//
//  ContentView.swift
//  Weather
//
//  Created by yasarkilic on 23.08.2023.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @ObservedObject var viewModel = WeatherViewModel()
    @State private var searchText = ""
    @State private var coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D() {
        didSet {
            region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
        }
    }
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
    
    var body: some View {
        ZStack {
            BackgroundView(topColor: viewModel.isNight ? .black : .blue, bottomColor: viewModel.isNight ? .gray : Color("lightBlue"))
            VStack {
                HStack {
                    TextField("Şehir ara", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.leading)
                    Button(action: {
                        viewModel.addCity(city: searchText)
                        getCoordinate(cityName: searchText)
                    }, label: {
                        Text("Ekle")
                    }).foregroundColor(.white)
                }
                .padding()
                
                Text(viewModel.cityName)
                    .font(.system(size: 32, weight: .medium, design: .default))
                    .foregroundColor(.white)
                    .padding()
                
                VStack(spacing: 10) {
                    Image(systemName: viewModel.weatherIcon)
                        .renderingMode(.original)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 180, height: 180)
                    
                    Text(viewModel.temperature)
                        .font(.system(size: 70, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.bottom, 40)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(viewModel.cities, id: \.self) { city in
                            VStack {
                                Text(city)
                                Image(systemName: viewModel.getWeatherIcon(city: city))
                                    .renderingMode(.original)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 30, height: 30)
                                Text(viewModel.getTemperature(city: city))
                                Button(action: {
                                    viewModel.removeCity(city: city)
                                }) {
                                    Text("Kaldır")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.3))
                            .cornerRadius(10)
                            .onTapGesture {
                                viewModel.selectedCity = city
                                viewModel.fetchWeather(city: city)
                                getCoordinate(cityName: city)
                            }
                        }
                    }
                }
                
                CityMapView(region: $viewModel.region)
                    .cornerRadius(15)
                    .padding()
                
                
                Spacer()
            }
        }
    }
    
    func getCoordinate(cityName: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(cityName) { (placemarks, error) in
            if let coordinate = placemarks?.first?.location?.coordinate {
                DispatchQueue.main.async {
                    viewModel.coordinate = coordinate
                }
            }
        }
    }
    
    
    struct CityMapView: View {
        @Binding var region: MKCoordinateRegion
        
        init(region: Binding<MKCoordinateRegion>) {
            _region = region
        }
        
        var body: some View {
            Map(coordinateRegion: $region)
        }
    }
    
    
    struct WeatherData: Decodable {
        let main: Main
        let weather: [Weather]
        let name: String
    }
    
    struct Main: Decodable {
        let temp: Double
    }
    
    struct Weather: Decodable {
        let id: Int
    }
    
    class WeatherViewModel: ObservableObject {
        @Published var isNight: Bool = false
        @Published var temperature: String = "Yükleniyor..."
        @Published var weatherIcon: String = "cloud"
        @Published var cityName: String = "Yükleniyor..."
        @Published var selectedCity: String = "Kadikoy"
        @Published var cities = ["Kadikoy", "Istanbul", "Londra", "Izmir"]
        @Published var coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D() {
            didSet {
                region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
            }
        }
        @Published var region: MKCoordinateRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
        private var cityWeather: [String: WeatherData] = [:]
        private var timer: Timer?
        
        init() {
            timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                let currentDate = Date()
                let calendar = Calendar.current
                let currentHour = calendar.component(.hour, from: currentDate)
                let currentMinute = calendar.component(.minute, from: currentDate)
                
                
                
                
                
                self.isNight = currentHour > 19 || (currentHour == 19 && currentMinute > 51)
                
                
            }
            
            
            
            for city in cities {
                fetchWeather(city: city)
            }
        }
        
        func addCity(city: String) {
            let formattedCity = city.replacingOccurrences(of: " ", with: "-")
            if !cities.contains(formattedCity) {
                cities.append(formattedCity)
                fetchWeather(city: formattedCity)
                
               
                selectedCity = formattedCity
                
                fetchWeather(city: selectedCity)
            }
        }
        
        func removeCity(city: String) {
            if let index = cities.firstIndex(of: city) {
                cities.remove(at: index)
            }
        }
        
        func fetchWeather(city: String) {
            guard let url = URL(string: "https://api.openweathermap.org/data/2.5/weather?q=\(city)&appid=4118e30b4e456192f645994f0c4423f5&units=metric") else { return }
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let data = data, error == nil {
                    do {
                        let weatherData = try JSONDecoder().decode(WeatherData.self, from: data)
                        DispatchQueue.main.async {
                            self.cityWeather[city] = weatherData
                            if city == self.selectedCity {
                                self.temperature = "\(weatherData.main.temp)°"
                                self.weatherIcon = self.mapWeatherIcon(weatherId: weatherData.weather.first?.id ?? 0)
                                self.cityName = weatherData.name
                            }
                        }
                    } catch {
                        print(error)
                    }
                }
            }.resume()
        }
        
        func getWeatherIcon(city: String) -> String {
            guard let weatherData = cityWeather[city] else { return "cloud" }
            return mapWeatherIcon(weatherId: weatherData.weather.first?.id ?? 0)
        }
        
        func getTemperature(city: String) -> String {
            guard let weatherData = cityWeather[city] else { return "Yükleniyor..." }
            return "\(weatherData.main.temp)°"
        }
        
        func mapWeatherIcon(weatherId: Int) -> String {
            switch weatherId {
            case 200...232: return "cloud.bolt.rain.fill"
            case 300...321: return "cloud.drizzle.fill"
            case 500...531: return "cloud.rain.fill"
            case 600...622: return "cloud.snow.fill"
            case 701...781: return "cloud.fog.fill"
            case 800: return "sun.max.fill"
            case 801...804: return "cloud.fill"
            default: return "cloud"
            }
        }
    }
    
    struct BackgroundView: View {
        var topColor: Color
        var bottomColor: Color
        
        var body: some View {
            LinearGradient(gradient: Gradient(colors: [topColor, bottomColor]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        }
    }
    
    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            ContentView()
        }
    }
}
