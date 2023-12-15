//
//  PaywallUIView.swift
//  ApphudDemoSwiftUI
//
//  Created by Renat Kurbanov on 15.02.2023.
//

import SwiftUI
import ApphudSDK
import StoreKit

// should be equal to identifier in your Apphud > Paywalls
enum PlacementID: String {
    case main
    case onboarding
}

struct PaywallUIView: View {

    @Environment(\.presentationMode) var presentationMode

    @State var placement: ApphudPlacement?
    @State var selectedProduct: ApphudProduct?

    @State var isPurchasing = false
    @State var purchaseSheetVisible = false

    @State var products = [Product]()

    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                Text("Apphud Premium")
                    .font(.system(size: 40, weight: .bold))

                planOptionsView()

                Spacer()
                purchaseButton()
            }
            .navigationBarItems(leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }, label: {Image(systemName: "xmark")}).disabled(isPurchasing),
                                trailing: Button("Restore") {
                Task {
                    isPurchasing = true
                    await Apphud.restorePurchases()
                    if AppVariables.isPremium {
                        presentationMode.wrappedValue.dismiss()
                    }
                    isPurchasing = false
                }
            }.disabled(isPurchasing))
        }
        .alert("Select Purchase Mode", isPresented: $purchaseSheetVisible, actions: {
            Button("Purchase SKProduct") {
                startPurchaseStoreKit1()
            }
            Button("Purchase Product Struct") {
                startPurchaseStoreKit2()
            }
            Button("Cancel", role: .cancel) {}
        })
        .interactiveDismissDisabled(isPurchasing)
        .task {
            if let place = await Apphud.placement(PlacementID.onboarding.rawValue) {
                placement = place
                selectedProduct = placement?.paywall?.products.first
            }

            do {
                products = try await Apphud.fetchProducts()
                print("Fetched StoreKit2 Products: \(products.map { $0.id })")
            } catch {
                print("Failed to fetch StoreKit2 Products error: \(error)")
            }
        }
    }

    func planOptionsView() -> some View {
        VStack(spacing: 15) {
            ForEach(placement?.paywall?.products ?? [], id: \.productId) { product in
                HStack {
                    paywallOptionView(product)
                }
            }
        }
        .padding([.leading, .trailing])
    }

    func purchaseButton() -> some View {
        Button {
            purchaseSheetVisible.toggle()
        } label: {
            HStack {
                Image(systemName: "arrow.right")
                    .foregroundColor(.white)
                    .padding(.trailing, 20)
                    .hidden()
                Spacer()
                Text(isPurchasing ? "Please, wait..." : "Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundColor(.white)
                    .padding(.trailing, 20)
            }
        }
        .frame(height: 70)
        .background(
            LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing)
        )
        .cornerRadius(20)
        .padding()
        .disabled(selectedProduct == nil || isPurchasing)
        .opacity(selectedProduct == nil || isPurchasing ? 0.5 : 1.0)
    }

    func paywallOptionView(_ product: ApphudProduct) -> some View {

        Button {
            selectedProduct = product
        } label: {
            HStack(spacing: 10) {
                Text(product.skProduct?.pricingDescription() ?? "")
                    .foregroundColor(Color(.label))
                Spacer()
                Image(systemName: selectedProduct == product ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedProduct == product ? .accentColor : Color(.label).opacity(0.1))
            }
            .padding()
            .frame(height: 70)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(selectedProduct == product ? Color.accentColor : Color(.label).opacity(0.1), lineWidth: 2.0)
            }
        }
    }

    func startPurchaseStoreKit1() {
        guard let product = selectedProduct else {return}
        Task { @MainActor in
            let result = await Apphud.purchase(product, isPurchasing: $isPurchasing)
            if result.success {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }

    func startPurchaseStoreKit2() {
        guard let product = selectedProduct else {return}

        Task { @MainActor in
            guard let productStruct = try? await product.product() else {
                return
            }
//            Apphud.setCustomPurchaseValue(1.23, productId: product.productId)
            let result = await Apphud.purchase(productStruct, isPurchasing: $isPurchasing)
            if result.success {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct PaywallUIView_Previews: PreviewProvider {
    static var previews: some View {
        PaywallUIView()
    }
}
