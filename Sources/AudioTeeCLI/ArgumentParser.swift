import Foundation

// MARK: - Error Types

enum ArgumentParserError: Error, CustomStringConvertible {
  case unknownOption(String)
  case missingValue(String)
  case invalidValue(String, String)
  case validationFailed(String)
  case helpRequested

  var description: String {
    switch self {
    case .unknownOption(let option):
      return "Unknown option: \(option)"
    case .missingValue(let option):
      return "Missing value for option: \(option)"
    case .invalidValue(let option, let value):
      return "Invalid value '\(value)' for option: \(option)"
    case .validationFailed(let message):
      return message
    case .helpRequested:
      return ""  // Help is handled separately
    }
  }
}

// MARK: - Argument Configuration

struct ArgumentConfig {
  let name: String
  let shortName: String?
  let help: String
  let isFlag: Bool
  let isArray: Bool
  let defaultValue: String?

  init(
    name: String, shortName: String? = nil, help: String, isFlag: Bool = false,
    isArray: Bool = false, defaultValue: String? = nil
  ) {
    self.name = name
    self.shortName = shortName
    self.help = help
    self.isFlag = isFlag
    self.isArray = isArray
    self.defaultValue = defaultValue
  }
}

// MARK: - Simple Argument Parser

class SimpleArgumentParser {
  private let programName: String
  private let abstract: String
  private let discussion: String
  private var configs: [ArgumentConfig] = []
  private var parsedValues: [String: [String]] = [:]

  init(programName: String, abstract: String, discussion: String = "") {
    self.programName = programName
    self.abstract = abstract
    self.discussion = discussion
  }

  func addOption(name: String, shortName: String? = nil, help: String, defaultValue: String? = nil)
  {
    configs.append(
      ArgumentConfig(name: name, shortName: shortName, help: help, defaultValue: defaultValue))
  }

  func addArrayOption(name: String, shortName: String? = nil, help: String) {
    configs.append(ArgumentConfig(name: name, shortName: shortName, help: help, isArray: true))
  }

  func addFlag(name: String, shortName: String? = nil, help: String) {
    configs.append(ArgumentConfig(name: name, shortName: shortName, help: help, isFlag: true))
  }

  func parse(_ arguments: [String] = Array(CommandLine.arguments.dropFirst())) throws {
    var i = 0

    while i < arguments.count {
      let arg = arguments[i]

      if arg == "--help" || arg == "-h" {
        throw ArgumentParserError.helpRequested
      }

      guard arg.hasPrefix("-") else {
        throw ArgumentParserError.unknownOption(arg)
      }

      let optionName = findOptionName(arg)
      guard let config = findConfig(optionName) else {
        throw ArgumentParserError.unknownOption(arg)
      }

      if config.isFlag {
        parsedValues[config.name] = ["true"]
        i += 1
      } else {
        // Need a value
        i += 1
        guard i < arguments.count else {
          throw ArgumentParserError.missingValue(arg)
        }

        if config.isArray {
          // Collect all values until next option or end
          var values: [String] = []
          while i < arguments.count && !arguments[i].hasPrefix("-") {
            values.append(arguments[i])
            i += 1
          }
          if values.isEmpty {
            throw ArgumentParserError.missingValue(arg)
          }
          parsedValues[config.name] = values
        } else {
          let value = arguments[i]
          parsedValues[config.name] = [value]
          i += 1
        }
      }
    }

    // Set default values for missing options
    for config in configs {
      if parsedValues[config.name] == nil, let defaultValue = config.defaultValue {
        parsedValues[config.name] = [defaultValue]
      }
    }
  }

  private func findOptionName(_ arg: String) -> String {
    if arg.hasPrefix("--") {
      return String(arg.dropFirst(2))
    } else if arg.hasPrefix("-") {
      return String(arg.dropFirst(1))
    }
    return arg
  }

  private func findConfig(_ optionName: String) -> ArgumentConfig? {
    return configs.first { config in
      config.name == optionName || config.shortName == optionName
    }
  }

  func getValue<T>(_ name: String, as type: T.Type) throws -> T {
    guard let values = parsedValues[name], let value = values.first else {
      throw ArgumentParserError.missingValue(name)
    }

    return try convertValue(value, to: type, optionName: name)
  }

  func getOptionalValue<T>(_ name: String, as type: T.Type) throws -> T? {
    guard let values = parsedValues[name], let value = values.first else {
      return nil
    }

    return try convertValue(value, to: type, optionName: name)
  }

  func getArrayValue<T>(_ name: String, as type: T.Type) throws -> [T] {
    guard let values = parsedValues[name] else {
      return []
    }

    return try values.map { try convertValue($0, to: type, optionName: name) }
  }

  func getFlag(_ name: String) -> Bool {
    return parsedValues[name]?.first == "true"
  }

  private func convertValue<T>(_ value: String, to type: T.Type, optionName: String) throws -> T {
    if type == String.self {
      return value as! T
    } else if type == Int32.self {
      guard let intValue = Int32(value) else {
        throw ArgumentParserError.invalidValue(optionName, value)
      }
      return intValue as! T
    } else if type == Double.self {
      guard let doubleValue = Double(value) else {
        throw ArgumentParserError.invalidValue(optionName, value)
      }
      return doubleValue as! T
    }

    throw ArgumentParserError.invalidValue(optionName, value)
  }

  func printHelp() {
    print(abstract)

    if !discussion.isEmpty {
      print("\n\(discussion)")
    }

    print("\nUSAGE:")
    print("    \(programName) [OPTIONS]")

    let optionConfigs = configs.filter { !$0.isFlag }
    let flagConfigs = configs.filter { $0.isFlag }

    if !optionConfigs.isEmpty {
      print("\nOPTIONS:")
      for config in optionConfigs {
        let shortName = config.shortName.map { "-\($0), " } ?? ""
        let defaultDesc = config.defaultValue.map { " (default: \($0))" } ?? ""
        print("    \(shortName)--\(config.name)    \(config.help)\(defaultDesc)")
      }
    }

    if !flagConfigs.isEmpty {
      print("\nFLAGS:")
      for config in flagConfigs {
        let shortName = config.shortName.map { "-\($0), " } ?? ""
        print("    \(shortName)--\(config.name)    \(config.help)")
      }
    }

    print("\n    -h, --help    Show this help message")
  }
}
