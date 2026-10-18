import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        let (url, key) = SupabaseManager.loadConfig()
        self.client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }

    static func loadConfig() -> (URL, String) {
        guard let path = Bundle.main.path(forResource: "SupabaseConfig", ofType: "plist") else {
            fatalError("SupabaseConfig.plist not found in bundle. Add it to the favorium target.")
        }
        guard let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            fatalError("SupabaseConfig.plist could not be read as a dictionary. Check the file format.")
        }
        
        // Temporary diagnostic — remove after fixing
        print("Plist keys found:", dict.keys.sorted())
        print("SUPABASE_URL value:", dict["SUPABASE_URL"] as Any)

        
        guard let urlString = dict["SUPABASE_URL"] as? String, !urlString.isEmpty else {
            fatalError("SupabaseConfig.plist is missing the SUPABASE_URL key or it is empty.")
        }
        guard let key = dict["SUPABASE_ANON_KEY"] as? String, !key.isEmpty else {
            fatalError("SupabaseConfig.plist is missing the SUPABASE_ANON_KEY key or it is empty.")
        }
        guard let url = URL(string: urlString) else {
            fatalError("SUPABASE_URL '\(urlString)' is not a valid URL.")
        }
        return (url, key)
    }
}
