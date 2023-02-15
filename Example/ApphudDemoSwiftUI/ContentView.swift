//
//  ContentView.swift
//  ApphudDemoSwiftUI
//
//  Created by Renat Kurbanov on 15.02.2023.
//

import SwiftUI
import ApphudSDK

struct ContentView: View {

    @State var isPaywallPresented: Bool = false
    @State var updateCounter = 0

    var body: some View {
        VStack {
            Image("logo")
                .resizable()
                .aspectRatio(1.0, contentMode: .fit)
                .frame(height: 80)
            Text("Apphud")
                .font(.largeTitle)
            Text("Premium is: " + premiumStatus + (updateCounter > 0 ? "" : ""))

            Button("Redeem Promo Code") {
                Apphud.presentOfferCodeRedemptionSheet()
            }
            .font(.headline)
            .padding()
        
            Button("Get Premium") {
                isPaywallPresented.toggle()
            }
            .font(.headline)
            .buttonStyle(.bordered)
            .padding()
        }
        .padding()
        .sheet(isPresented: $isPaywallPresented) {
            PaywallUIView()
        }
        .onReceive(NotificationCenter.default.publisher(for: Apphud.didUpdateNotification()), perform: {_ in
            print("did receive update notification")
            updateCounter += 1
        })
    }

    var premiumStatus: String {
        AppVariables.isPremium ? "ON" : "OFF"
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
