import Foundation

class TranslationServiceFactory {
    static func createService(settings: AppSettings) -> TranslationServiceProtocol {
        #if compiler(>=5.9) && os(iOS)
        if #available(iOS 18.2, *) {
            print("[TranslationServiceFactory] using FoundationModelsTranslationService (on-device)")
            return FoundationModelsTranslationService()
        } else {
            print("[TranslationServiceFactory] FoundationModels may not be available on this OS; using service anyway")
            return FoundationModelsTranslationService()
        }
        #else
        return FoundationModelsTranslationService()
        #endif
    }
}
