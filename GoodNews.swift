import SwiftUI
import WebKit
import UIKit

// MARK: - Model Data
struct Article: Identifiable, Codable, Hashable {
    var id: String
    let title: String
    let url: String
    let status: String
}

struct LoginRequest: Codable {
    let username: String
    let password: String
}

struct LoginResponse: Codable {
    let access_token: String
}

struct CreateArticleRequest: Codable {
    let title: String
    let url: String
    let status: String
    let publish_at: String?
}

// MARK: - API Service
class APIService {
    static let shared = APIService()
    private let baseURL = "http://oci-builder-1.collie-koi.ts.net:8000"
    
    private var jwtToken: String? {
        get { UserDefaults.standard.string(forKey: "jwtToken") }
        set { UserDefaults.standard.setValue(newValue, forKey: "jwtToken") }
    }
    
    func login(username: String, password: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/login") else { return }
        
        let loginData = LoginRequest(username: username, password: password)
        guard let jsonData = try? JSONEncoder().encode(loginData) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, _ in
            guard let data = data,
                  let response = try? JSONDecoder().decode(LoginResponse.self, from: data) else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            self.jwtToken = response.access_token
            DispatchQueue.main.async { completion(true) }
        }.resume()
    }
    
    func fetchArticles(completion: @escaping ([Article]) -> Void) {
        guard let url = URL(string: "\(baseURL)/articles") else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let articles = try? JSONDecoder().decode([Article].self, from: data) else { return }
            
            DispatchQueue.main.async { completion(articles) }
        }.resume()
    }
    
    func createArticle(title: String, url: String, status: String, publishDate: Date?, completion: @escaping (Bool) -> Void) {
        guard let apiURL = URL(string: "\(baseURL)/articles") else { return }
        guard let token = jwtToken else {
            completion(false)
            return
        }
        
        let dateFormatter = ISO8601DateFormatter()
        let publish_at = publishDate != nil ? dateFormatter.string(from: publishDate!) : nil
        
        let newArticle = CreateArticleRequest(title: title, url: url, status: status, publish_at: publish_at)
        guard let jsonData = try? JSONEncoder().encode(newArticle) else { return }
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network Error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Response Code: \(httpResponse.statusCode)")
                if !(200...299).contains(httpResponse.statusCode) {
                    DispatchQueue.main.async { completion(false) }
                    return
                }
            }
            
            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                print("Response Body: \(responseString)")
            }
            
            DispatchQueue.main.async { completion(true) }
        }.resume()
    }
    
    func updateArticle(articleId: String, title: String, url: String, status: String, publishDate: Date?, completion: @escaping (Bool) -> Void) {
        guard let apiURL = URL(string: "\(baseURL)/articles/\(articleId)") else { return }
        guard let token = jwtToken else {
            completion(false)
            return
        }
        
        let dateFormatter = ISO8601DateFormatter()
        let publish_at = publishDate != nil ? dateFormatter.string(from: publishDate!) : nil
        
        let updatedArticle = CreateArticleRequest(title: title, url: url, status: status, publish_at: publish_at)
        guard let jsonData = try? JSONEncoder().encode(updatedArticle) else { return }
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "PUT"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network Error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Response Code: \(httpResponse.statusCode)")
                if !(200...299).contains(httpResponse.statusCode) {
                    DispatchQueue.main.async { completion(false) }
                    return
                }
            }
            
            DispatchQueue.main.async { completion(true) }
        }.resume()
    }
}

// MARK: - WebView
struct WebView: UIViewRepresentable {
    let url: URL
    var isDarkMode: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
        
        // Dark mode injection menggunakan JavaScript
        let darkModeJS = """
        (function() {
            var darkModeStyle = document.getElementById('darkModeStyle');
            if (\(isDarkMode ? "true" : "false")) {
                if (!darkModeStyle) {
                    darkModeStyle = document.createElement('style');
                    darkModeStyle.id = 'darkModeStyle';
                    darkModeStyle.innerHTML = `
                        body { background-color: #000 !important; color: #fff !important; }
                        p, div, span, h1, h2, h3, h4, h5, h6 { background-color: inherit !important; color: inherit !important; }
                        img, video { filter: none !important; }
                    `;
                    document.head.appendChild(darkModeStyle);
                }
            } else {
                if (darkModeStyle) {
                    darkModeStyle.remove();
                }
            }
        })();
        """
        
        webView.evaluateJavaScript(darkModeJS, completionHandler: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        // Terapkan dark mode setelah halaman selesai dimuat
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let syncDarkModeJS = """
            (function() {
                var darkModeStyle = document.getElementById('darkModeStyle');
                if (\(parent.isDarkMode ? "true" : "false")) {
                    if (!darkModeStyle) {
                        darkModeStyle = document.createElement('style');
                        darkModeStyle.id = 'darkModeStyle';
                        darkModeStyle.innerHTML = `
                            body { background-color: #000 !important; color: #fff !important; }
                            p, div, span, h1, h2, h3, h4, h5, h6 { background-color: inherit !important; color: inherit !important; }
                            img, video { filter: none !important; }
                        `;
                        document.head.appendChild(darkModeStyle);
                    }
                }
            })();
            """
            webView.evaluateJavaScript(syncDarkModeJS, completionHandler: nil)
        }
    }
}

// MARK: - UserView
struct UserView: View {
    @State private var articles: [Article] = []
    @State private var selectedArticle: Article?
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    var body: some View {
        NavigationSplitView {
            List(articles, selection: $selectedArticle) { article in
                Text(article.title)
                    .font(.headline)
                    .padding(.vertical, 4)
                    .tag(article)
            }
            .navigationTitle("Articles")
            .toolbar {
                Button(action: { isDarkMode.toggle() }) {
                    Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                }
            }
        } detail: {
            if let article = selectedArticle, let articleURL = URL(string: article.url) {
                WebView(url: articleURL, isDarkMode: isDarkMode).ignoresSafeArea()
            } else {
                Text("Select an article to read").foregroundColor(.gray).font(.title2)
            }
        }
        .onAppear {
            APIService.shared.fetchArticles { self.articles = $0 }
        }
    }
}

// MARK: - LoginView
struct LoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var isAuthenticated = false
    @State private var loginFailed = false
    
    var body: some View {
        VStack {
            if isAuthenticated {
                AdminView(isAuthenticated: $isAuthenticated)
            } else {
                VStack(spacing: 20) {
                    Text("Admin Login")
                        .font(.largeTitle)
                        .bold()
                    
                    VStack(spacing: 15) {
                        TextField("Username", text: $username)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .shadow(radius: 1)
                        
                        SecureField("Password", text: $password)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .shadow(radius: 1)
                    }
                    .padding(.horizontal, 40)
                    
                    Button(action: {
                        APIService.shared.login(username: username, password: password) { success in
                            if success {
                                isAuthenticated = true
                            } else {
                                loginFailed = true
                            }
                        }
                    }) {
                        Text("Login")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                            .shadow(radius: 2)
                    }
                    .padding(.horizontal, 40)
                    
                    if loginFailed {
                        Text("Invalid credentials")
                            .foregroundColor(.red)
                            .bold()
                    }
                }
                .frame(maxWidth: 400)
                .padding()
                .background(RoundedRectangle(cornerRadius: 15).fill(Color(.systemBackground)).shadow(radius: 5))
                .padding()
            }
        }
    }
}

// MARK: - AdminView
struct AdminView: View {
    @State private var selectedTab = "Create"
    
    @State private var articles: [Article] = []
    @State private var selectedArticle: Article?
    
    @State private var title = ""
    @State private var url = ""
    @State private var status = "published"
    @State private var publishDate = Date()
    
    @State private var saveSuccess = false
    @State private var saveFailed = false
    @State private var updateSuccess = false
    @State private var updateFailed = false
    
    @Binding var isAuthenticated: Bool  // Untuk mengontrol logout
    
    var body: some View {
        VStack {
            Picker("Mode", selection: $selectedTab) {
                Text("Create").tag("Create")
                Text("Update").tag("Update")
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(maxWidth: 400)
            .padding()
            
            if selectedTab == "Create" {
                createArticleView()
            } else {
                updateArticleView()
            }
            
            Button(action: logout) {
                Text("Logout")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth:335)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(10)
                    .shadow(radius: 2)
            }
            .padding(.horizontal, 40)
            .padding(.top, 10)
        }
        .onAppear {
            APIService.shared.fetchArticles { self.articles = $0 }
        }
    }
    
    // MARK: - Logout Function
    private func logout() {
        UserDefaults.standard.removeObject(forKey: "jwtToken")
        isAuthenticated = false
    }
    
    // MARK: - Create Article
    private func createArticleView() -> some View {
        VStack(spacing: 20) {
            Text("Add New Article")
                .font(.largeTitle)
                .bold()
            
            articleForm()
            
            Button(action: {
                APIService.shared.createArticle(title: title, url: url, status: status, publishDate: publishDate) { success in
                    if success {
                        saveSuccess = true
                        saveFailed = false
                    } else {
                        saveFailed = true
                        saveSuccess = false
                    }
                }
            }) {
                Text("Save")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                    .shadow(radius: 2)
            }
            
            if saveSuccess {
                Text("Article saved!").foregroundColor(.green).bold()
            }
            
            if saveFailed {
                Text("Failed to save article").foregroundColor(.red).bold()
            }
        }
        .padding()
        .frame(maxWidth: 400)
        .background(RoundedRectangle(cornerRadius: 15).fill(Color(.systemBackground)).shadow(radius: 5))
        .padding()
    }
    
    // MARK: - Update Article
    private func updateArticleView() -> some View {
        VStack(spacing: 20) {
            Text("Update Article")
                .font(.largeTitle)
                .bold()
            
            Picker("Select Article", selection: $selectedArticle) {
                Text("Select an article").tag(nil as Article?)
                ForEach(articles, id: \.self) { article in
                    Text(article.title).tag(article as Article?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding()
            
            if let selected = selectedArticle {
                articleForm()
                
                Button(action: {
                    APIService.shared.updateArticle(articleId: selected.id, title: title, url: url, status: status, publishDate: status == "published" ? publishDate : nil) { success in
                        if success {
                            updateSuccess = true
                            updateFailed = false
                        } else {
                            updateFailed = true
                            updateSuccess = false
                        }
                    }
                }) {
                    Text("Update")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                }
                
                if updateSuccess {
                    Text("Article updated!").foregroundColor(.green).bold()
                }
                
                if updateFailed {
                    Text("Failed to update article").foregroundColor(.red).bold()
                }
            } else {
                Text("Select an article to update")
                    .foregroundColor(.gray)
                    .font(.title2)
            }
        }
        .padding()
        .frame(maxWidth: 400)
        .background(RoundedRectangle(cornerRadius: 15).fill(Color(.systemBackground)).shadow(radius: 5))
        .padding()
        .task(id: selectedArticle) {
            if let article = selectedArticle {
                title = article.title
                url = article.url
                status = article.status
            }
        }
    }
    
    // MARK: - Reusable Form
    private func articleForm() -> some View {
        VStack(spacing: 15) {
            TextField("Title", text: $title)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .shadow(radius: 1)
            
            TextField("URL", text: $url)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .shadow(radius: 1)
            
            Picker("Status", selection: $status) {
                Text("Published").tag("published")
                Text("Unpublished").tag("unpublished")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            if status == "published" {
                DatePicker("Publish Date", selection: $publishDate, displayedComponents: .date)
                    .padding()
            }
        }
    }
}

// MARK: - ContentView
struct ContentView: View {
    var body: some View {
        TabView {
            UserView()
                .tabItem { Label("User", systemImage: "list.bullet") }
            LoginView()
                .tabItem { Label("Admin", systemImage: "person.fill") }
        }
    }
}
