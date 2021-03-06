import Foundation
import SourceKittenFramework

public struct BlockBasedKVORule: ASTRule, ConfigurationProviderRule, AutomaticTestableRule {
    public var configuration = SeverityConfiguration(.warning)

    public init() {}

    public static let description = RuleDescription(
        identifier: "block_based_kvo",
        name: "Block Based KVO",
        description: "Prefer the new block based KVO API with keypaths when using Swift 3.2 or later.",
        kind: .idiomatic,
        nonTriggeringExamples: [
            """
            let observer = foo.observe(\\.value, options: [.new]) { (foo, change) in
               print(change.newValue)
            }
            """
        ],
        triggeringExamples: [
            """
            class Foo: NSObject {
              override ↓func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                          change: [NSKeyValueChangeKey : Any]?,
                                          context: UnsafeMutableRawPointer?) {}
            }
            """
           ,
            """
            class Foo: NSObject {
              override ↓func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                          change: Dictionary<NSKeyValueChangeKey, Any>?,
                                          context: UnsafeMutableRawPointer?) {}
            }
            """
        ]
    )

    public func validate(file: File, kind: SwiftDeclarationKind,
                         dictionary: [String: SourceKitRepresentable]) -> [StyleViolation] {
        guard SwiftVersion.current >= .four, kind == .functionMethodInstance,
            dictionary.enclosedSwiftAttributes.contains(.override),
            dictionary.name == "observeValue(forKeyPath:of:change:context:)",
            hasExpectedParamTypes(types: dictionary.enclosedVarParameters.parameterTypes),
            let offset = dictionary.offset else {
                return []
        }

        return [
            StyleViolation(ruleDescription: type(of: self).description,
                           severity: configuration.severity,
                           location: Location(file: file, byteOffset: offset))
        ]
    }

    private func hasExpectedParamTypes(types: [String]) -> Bool {
        guard types.count == 4,
            types[0] == "String?",
            types[1] == "Any?",
            types[2] == "[NSKeyValueChangeKey:Any]?" || types[2] == "Dictionary<NSKeyValueChangeKey,Any>?",
            types[3] == "UnsafeMutableRawPointer?" else {
                return false
        }

        return true
    }
}

private extension Array where Element == [String: SourceKitRepresentable] {
    var parameterTypes: [String] {
        return compactMap { element in
            guard element.kind.flatMap(SwiftDeclarationKind.init) == .varParameter else {
                return nil
            }

            return element.typeName?.replacingOccurrences(of: " ", with: "")
        }
    }
}
