//
//  MultiColorText.swift
//  IngrediCheck
//
//  Created by Gaurav on 09/01/26.
//
import SwiftUI
struct MultiColorText: View {
    var text: String
    var delimiter: Character = "*"
        
      //                    .foregroundStyle(.grayScale140)
    var font: Font = ManropeFont.bold.size(14)
    var body: some View {
        let components = text.components(separatedBy: String(delimiter))
        return components.enumerated().reduce(Text("")) { (currentText, indexAndString) in
            let (index, part) = indexAndString
            // Even index = Black (Default)
            // Odd index = Highlight Color (#7B8288)
            let color = index % 2 == 0 ? Color.grayScale140 : Color.grayScale90
            return currentText + Text(part).foregroundColor(color)
        }
        .font(font)
    }
}
#Preview {
    VStack(spacing: 20) {
        MultiColorText(text: "Are you *a* new user *or an* existing one?", font: NunitoFont.black.size(20))
            .multilineTextAlignment(.center)
        MultiColorText(text: "Simply *Highlight* anything easily!")
            .multilineTextAlignment(.center)
    }
    .padding()
}
