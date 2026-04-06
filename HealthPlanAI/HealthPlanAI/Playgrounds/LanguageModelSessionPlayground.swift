import FoundationModels
import Playgrounds

#Playground {
    let instructions = """
    You are a motivational workout coach that provides quotes to inspire \
    and motivate athletes.
    """
    let session = LanguageModelSession(model: .default, instructions: instructions)
    let prompt = "Generate a motivational quote for my next workout."
    let response = session.streamResponse(to: prompt)
    
    for try await chunk in response {
        print("\n" + chunk.content)
    }
}
