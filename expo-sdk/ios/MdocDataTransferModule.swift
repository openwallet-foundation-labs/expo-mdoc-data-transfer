import ExpoModulesCore
import MdocProximity

public class MdocDataTransferModule: Module {
    public func definition() -> ModuleDefinition {
        Name("MdocDataTransfer")
        
        Function("hello") { () -> String in 
            Greeting().greet()
        }
    }
}
