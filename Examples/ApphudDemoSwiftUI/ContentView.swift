//
//  ContentView.swift
//  ApphudDemoSwiftUI
//
//  Created by Renat Kurbanov on 15.02.2023.
//

import SwiftUI
//import ApphudSDK
import StoreKit
import AppMetricaCore

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
//                Apphud.presentOfferCodeRedemptionSheet()
            }
            .font(.headline)
            .padding()
            
            Button("Purchase Monthly2") {
                Task { @MainActor in
                    await self.purchaseMonthly2Manually()
                }
            }
            .font(.headline)
            .padding()
            
            Button("Purchase Weekly Manually") {
                Task { @MainActor in
                    await self.purchaseWeeklyManually()
                }
            }
            .font(.headline)
            .padding()
            
            Button("Purchase Monthly Manually") {
                Task { @MainActor in
                    await self.purchaseMonthlyManually()
                }
            }
            .font(.headline)
            .padding()

            Button("Finish All Transactions") {
                Task { @MainActor in
                    await self.finishAllTransactions()
                }
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
//            PaywallUIView()
        }
//        .onReceive(NotificationCenter.default.publisher(for: Apphud.didUpdateNotification()), perform: {_ in
//            print("did receive update notification")
//            updateCounter += 1
//        })
    }
    
    func purchaseGold() async {
        await purchase(productID: "com.apphud.gold")
    }
    
    func purchaseWeeklyManually() async {
        await purchase(productID: "com.apphud.weekly")
    }
    
    func purchaseMonthlyManually() async {
        await purchase(productID: "com.apphud.monthly_promo")
    }
    
    
    func purchaseMonthly2Manually() async {
        await purchase(productID: "com.apphud.monthly.trial")
    }
    
    
    @MainActor
    func purchase(productID: String) async {
        
        AppMetrica.reportEvent(name: "purchase_initiated", parameters: ["product_id": productID])
        
        do {
            let products = try await Product.products(for: [productID])
            if let product = products.first {
                let result = try await product.purchase()
                var transaction: StoreKit.Transaction?

                switch result {
                case .success(.verified(let trx)):
                    transaction = trx
                    print("purchased: \(trx.id)")
                case .success(.unverified(let trx, _)):
                    transaction = trx
                    print("purchase unverified: \(trx.id)")
                case .pending:
                    break
                case .userCancelled:
                    print("cancelled purchase")
                    AppMetrica.reportEvent(name: "purchase_canceled", parameters: ["product_id": productID])
                    break
                default:
                    break
                }

                if let transaction {
                    
                    AppMetrica.reportEvent(name: "purchased_product", parameters: ["product_id": productID])
                    
                    Task {
                        try await Task.sleep(nanoseconds: 3_000_000_000)
                        await transaction.finish()
                        print("Finished transaction: \(transaction.id) \(transaction.expirationDate?.description ?? "nil")")
                    }
                }
                
                AppMetrica.sendEventsBuffer()
            }
        } catch {
            print("purchase error: \(error)")
        }
        
//        Task {
//            for await result in StoreKit.Transaction.all {
//                switch result {
//                case .verified(let transaction):
//                    await transaction.finish()
//                case .unverified(let transaction, let error):
//                    print("Unverified transaction: \(transaction). Error: \(error)")
//                    // Handle unverified transactions if needed
//                }
//            }
//        }
    }
    
    @MainActor
    func finishAllTransactions() async {
        do {
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    // Process the transaction (e.g., unlock content or update subscription status)
//                    await handleTransaction(transaction)
                    
                    // Mark the transaction as finished
                    await transaction.finish()
                case .unverified(_, let error):
                    // Handle unverified transactions (e.g., log or alert user)
                    print("Unverified transaction: \(error.localizedDescription)")
                }
            }
        } catch {
            print("Error handling transactions: \(error.localizedDescription)")
        }
    }

    @MainActor
    var premiumStatus: String {
        AppVariables.isPremium ? "ON" : "OFF"
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
