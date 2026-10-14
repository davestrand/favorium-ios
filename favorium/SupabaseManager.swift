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
        guard
            let path = Bundle.main.path(forResource: "SupabaseConfig", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
            let urlString = dict["SUPABASE_URL"] as? String,
            let key = dict["SUPABASE_ANON_KEY"] as? String,
            let url = URL(string: urlString)
        else {
            fatalError("Missing or invalid SupabaseConfig.plist. Ensure SUPABASE_URL and SUPABASE_ANON_KEY are set.")
        }
        return (url, key)
    }
}
