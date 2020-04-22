//
//  AuthSignUpController.swift
//  Neverwhere
//
//  Created by Bartu Atabek on 8/30/19.
//  Copyright © 2019 Neverwhere. All rights reserved.
//

import UIKit
import LGButton
import MessageUI
import ReactiveSwift
import ReactiveCocoa
import IQKeyboardManagerSwift
import AuthenticationServices

class AuthSignUpController: UIViewController {

    var viewModel: AuthViewModeling?
    var isValidEmail = false, isValidPassword = false, passwordsMatch = false
    var returnKeyHandler: IQKeyboardReturnKeyHandler?

    var password: String?, confirmPassword: String?

    @IBOutlet weak var emailTextField: FormTextField!
    @IBOutlet weak var passwordTextField: FormTextField!
    @IBOutlet weak var confirmPasswordTextField: FormTextField!
    @IBOutlet weak var registerButton: LGButton!

    @IBOutlet weak var emailErrorLabel: UILabel!
    @IBOutlet weak var passwordErrorLabel: UILabel!
    @IBOutlet weak var confirmPasswordErrorLabel: UILabel!

    @IBOutlet weak var activityIndicatorContainer: UIView!
    @IBOutlet weak var signInWithAppleContainer: UIView!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.viewModel?.controller = self
        self.viewModel?.resetErrorMessages()
        bindUIElements()
        setupViews()
    }

    override func viewWillLayoutSubviews() {
           setupSignInWIthApple()
       }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
           super.traitCollectionDidChange(previousTraitCollection)
           setupSignInWIthApple()
       }

    // MARK: - ViewController Functions
    fileprivate func setupViews() {
        if isValidEmail && isValidPassword && passwordsMatch {
            registerButton.isEnabled = true
            registerButton.alpha = 1.0
        } else {
            registerButton.isEnabled = false
            registerButton.alpha = 0.75
        }
    }

    fileprivate func setupSignInWIthApple() {
        let userInterfaceStyle = traitCollection.userInterfaceStyle
        var authorizationButton: ASAuthorizationAppleIDButton

        if userInterfaceStyle == .light {
            authorizationButton = ASAuthorizationAppleIDButton(authorizationButtonType: .signIn, authorizationButtonStyle: .black)
        } else if userInterfaceStyle == .dark {
            authorizationButton = ASAuthorizationAppleIDButton(authorizationButtonType: .signIn, authorizationButtonStyle: .white)
        } else {
            authorizationButton = ASAuthorizationAppleIDButton(authorizationButtonType: .signIn, authorizationButtonStyle: .whiteOutline)
        }

        authorizationButton.cornerRadius = 25
        authorizationButton.contentMode = .scaleAspectFit
        authorizationButton.frame = signInWithAppleContainer.bounds
        authorizationButton.addTarget(self, action: #selector(handleAppleLogin), for: .touchUpInside)
        // Replace the previous button with new styled one
        signInWithAppleContainer.subviews.forEach({ $0.removeFromSuperview() })
        signInWithAppleContainer.addSubview(authorizationButton)
    }

    fileprivate func bindUIElements() {
        emailErrorLabel.reactive.text <~ viewModel!.topErrorLabelMessage
        passwordErrorLabel.reactive.text <~ viewModel!.middleErrorLabelMessage
        confirmPasswordErrorLabel.reactive.text <~ viewModel!.bottomErrorLabelMessage
        returnKeyHandler = IQKeyboardReturnKeyHandler(controller: self)
    }

    fileprivate func updatePasswordLabels() {
        if passwordTextField.text!.isEmpty && confirmPasswordErrorLabel.text!.isEmpty {
            viewModel?.resetErrorMessage(errorMessage: .middle)
            viewModel?.resetErrorMessage(errorMessage: .bottom)
        }

        setupViews()
    }

    // MARK: TextField Actions
    @IBAction func emailTextDidChange(_ sender: FormTextField) {
        emailTextField.text = emailTextField.text?.trimmingCharacters(in: .whitespaces)

        if let input = emailTextField.text, input.count > 0 {
                isValidEmail = (viewModel?.isValidEmail(email: sender.text))!
        } else if emailTextField.text!.isEmpty {
            isValidEmail = false
            viewModel?.resetErrorMessage(errorMessage: .top)
        }

        setupViews()
    }

    @IBAction func passwordTextDidChange(_ sender: FormTextField) {
        password = passwordTextField.text
        isValidPassword = (viewModel?.isSecurePassword(password: passwordTextField.text))!
        passwordsMatch = viewModel!.isPasswordsMatching(password: password, verify: confirmPassword)
        updatePasswordLabels()
    }

    @IBAction func passwordTextEditingDidEnd(_ sender: Any) {
        passwordTextField.text = password
    }

    @IBAction func confirmPasswordTextDidChange(_ sender: FormTextField) {
        confirmPassword = confirmPasswordTextField.text
        passwordsMatch = viewModel!.isPasswordsMatching(password: password, verify: confirmPassword)
        updatePasswordLabels()
    }

    @IBAction func confirmPasswordTextEditingDidEnd(_ sender: Any) {
        confirmPasswordTextField.text = confirmPassword
    }

    // MARK: - Button Actions
    @objc func handleAppleLogin() {
        activityIndicatorContainer.isHidden = false
        let request = viewModel?.startSignInWithAppleFlow()
        let authorizationController = ASAuthorizationController(authorizationRequests: [request!])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    @IBAction func handleSignUp(_ sender: Any) {
        emailTextField.resignFirstResponder()
        passwordTextField.resignFirstResponder()
        confirmPasswordTextField.resignFirstResponder()
        activityIndicatorContainer.isHidden = false
        registerButton.isLoading = true

        viewModel?.mailRegister(email: emailTextField.text!, password: passwordTextField.text!, completion: { (finished, result) in
            if finished && result {
                self.viewModel?.segueToHome()
            } else {
                self.activityIndicatorContainer.isHidden = true
                self.registerButton.isLoading = false
            }

        })

    }

    @IBAction func goToLogin(_ sender: Any) {
        if !(navigationController?.popToViewController(ofClass: AuthSignInController.self))! {
            let mainStoryboard = UIStoryboard(name: "Auth", bundle: nil)
            if let viewController = mainStoryboard.instantiateViewController(withIdentifier: "Login") as? AuthSignInController {
                viewController.viewModel = self.viewModel
                if let sender = sender as? FormTextField, sender == self.emailTextField {
                    viewController.isValidEmail = true
                    viewController.email = emailTextField.text!
                }
                navigationController?.pushViewController(viewController, animated: true)
            }
        }
    }
}

// MARK: - MFMailComposeViewControllerDelegate
extension AuthSignUpController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        dismiss(animated: true, completion: nil)
    }
}

@available(iOS 13.0, *)
extension AuthSignUpController: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {

        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = viewModel?.currentNonce.value else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("Unable to fetch identity token")
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                return
            }

            viewModel?.signInWithApple(idTokenString: idTokenString, nonce: nonce, completion: { (finished, result) in
                if finished && result {
                     self.viewModel?.segueToHome()
                } else {
                    self.activityIndicatorContainer.isHidden = true
                }
            })
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Handle error.
        print("Sign in with Apple errored: \(error)")
        self.activityIndicatorContainer.isHidden = true
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return view.window!
    }
}
