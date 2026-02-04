import Foundation
import SwiftUI

/// Centralized microcopy keys for v2.0 (preview flow).
///
/// Notes:
/// - Keys live in `IngrediCheck/Resources/Localizable.xcstrings`.
/// - Prefer `Microcopy.text(...)` for SwiftUI and `Microcopy.string(...)` for APIs/components that need a `String`.
enum Microcopy {
    // MARK: - Key constants

    enum Key {
        enum Common {
            static let back = "v2.common.cta.back"
            static let cancel = "v2.common.cta.cancel"
            static let confirm = "v2.common.cta.confirm"
            static let `continue` = "v2.common.cta.continue"
            static let done = "v2.common.cta.done"
            static let getStarted = "v2.common.cta.getStarted"
            static let invite = "v2.common.cta.invite"
            static let maybeLater = "v2.common.cta.maybeLater"
            static let notNow = "v2.common.cta.notNow"
            static let ok = "v2.common.cta.ok"
            static let openSettings = "v2.common.cta.openSettings"
            static let save = "v2.common.cta.save"
            static let signOut = "v2.common.cta.signOut"
            static let tryAgain = "v2.common.cta.tryAgain"
            static let viewAll = "v2.common.cta.viewAll"
        }

        enum Labels {
            static let foodNotes = "v2.common.label.foodNotes"
            static let ingredients = "v2.common.label.ingredients"
        }

        enum Onboarding {
            enum IngrediFamWelcome {
                static let title = "v2.onboarding.ingredifam.welcome.title"
                static let subtitle = "v2.onboarding.ingredifam.welcome.subtitle"
            }

            enum InviteCode {
                static let title = "v2.onboarding.inviteCode.title"
                static let subtitle = "v2.onboarding.inviteCode.subtitle"
                static let helper = "v2.onboarding.inviteCode.helper"
                static let error = "v2.onboarding.inviteCode.error"

                static let ctaVerifyContinue = "v2.onboarding.inviteCode.cta.verifyContinue"
                static let ctaClearCode = "v2.onboarding.inviteCode.cta.clearCode"
            }

            enum AddFoodNotesForMember {
                static let title = "v2.onboarding.addFoodNotesForMember.title"
                static let subtitle = "v2.onboarding.addFoodNotesForMember.subtitle"
                static let ctaAdd = "v2.onboarding.addFoodNotesForMember.cta.add"
            }
        }

        enum Family {
            static let overviewTitle = "v2.family.overview.title"
            static let youTag = "v2.family.overview.youTag"

            static let leaveFamily = "v2.family.leaveFamily.cta"
            static let leaveFamilyConfirmTitle = "v2.family.leaveFamily.confirm.title"
            static let leaveFamilyConfirmMessage = "v2.family.leaveFamily.confirm.message"

            static let statusPending = "v2.family.status.pending"
            static let statusNotJoinedYet = "v2.family.status.notJoinedYet"

            static let gettingStartedTitle = "v2.family.gettingStarted.title"
            static let gettingStartedSubtitle = "v2.family.gettingStarted.subtitle"
        }

        enum Auth {
            static let signInToContinueTitle = "v2.auth.signInToContinue.title"
            static let signInToContinueSubtitle = "v2.auth.signInToContinue.subtitle"

            static let signInFailedTitle = "v2.auth.signInFailed.title"
        }

        enum Permissions {
            static let title = "v2.permissions.title"
            static let subtitle = "v2.permissions.subtitle"

            enum Camera {
                static let title = "v2.permissions.camera.title"
                static let subtitle = "v2.permissions.camera.subtitle"
            }

            enum Notifications {
                static let title = "v2.permissions.notifications.title"
                static let subtitle = "v2.permissions.notifications.subtitle"
            }

            enum SignIn {
                static let title = "v2.permissions.signIn.title"
                static let subtitle = "v2.permissions.signIn.subtitle"
            }

            enum Alert {
                enum Camera {
                    static let title = "v2.permissions.alert.camera.title"
                    static let message = "v2.permissions.alert.camera.message"
                }

                enum Notifications {
                    static let title = "v2.permissions.alert.notifications.title"
                    static let message = "v2.permissions.alert.notifications.message"
                }
            }
        }

        enum Home {
            static let greeting = "v2.home.greeting"
            static let subtitle = "v2.home.subtitle"

            enum FoodNotes {
                static let familySubtitle = "v2.home.foodNotes.familySubtitle"
            }

            enum Family {
                static let title = "v2.home.family.title"
                static let subtitle = "v2.home.family.subtitle"
            }

            enum RecentScans {
                static let title = "v2.home.recentScans.title"
                static let subtitle = "v2.home.recentScans.subtitle"
                static let ctaViewAll = "v2.home.recentScans.cta.viewAll"
                static let emptyTitle = "v2.home.recentScans.empty.title"
            }
        }

        enum Lists {
            static let title = "v2.lists.title"

            enum Favorites {
                static let title = "v2.lists.favorites.title"
                static let emptyTitle = "v2.lists.favorites.empty.title"
                static let emptyDescription = "v2.lists.favorites.empty.description"
            }

            enum RecentScans {
                static let title = "v2.lists.recentScans.title"
                static let emptyTitle = "v2.lists.recentScans.empty.title"
            }
        }

        enum Scans {
            static let loading = "v2.scans.loading"

            enum Empty {
                static let title = "v2.scans.empty.title"
                static let description = "v2.scans.empty.description"
            }

            enum Cta {
                static let startScanning = "v2.scans.cta.startScanning"
            }
        }

        enum Product {
            enum MissingIngredients {
                static let title = "v2.product.missingIngredients.title"
                static let subtitle = "v2.product.missingIngredients.subtitle"

                static let message = "v2.product.missingIngredients.message"
                static let analyzeHint = "v2.product.missingIngredients.analyzeHint"
            }

            enum NotFound {
                static let title = "v2.product.notFound.title"
                static let subtitle = "v2.product.notFound.subtitle"
            }

            enum Ingredients {
                static let noneAvailable = "v2.product.ingredients.noneAvailable"
            }

            enum AlertCard {
                static let readMore = "v2.product.alertCard.readMore"
                static let readLess = "v2.product.alertCard.readLess"

                enum Fallback {
                    static let matched = "v2.product.alertCard.fallback.matched"
                    static let unmatched = "v2.product.alertCard.fallback.unmatched"
                }
            }

            enum Cta {
                static let addPhotos = "v2.product.cta.addPhotos"
            }

            enum Detail {
                static let title = "v2.product.detail.title"
            }
        }

        enum Settings {
            enum Toast {
                static let feedbackSubmitted = "v2.settings.toast.feedbackSubmitted"
            }

            enum Section {
                static let account = "v2.settings.section.account"
                static let settings = "v2.settings.section.settings"
                static let about = "v2.settings.section.about"
                static let supportUs = "v2.settings.section.supportUs"
                static let others = "v2.settings.section.others"
            }

            enum Row {
                static let startScanningOnLaunch = "v2.settings.row.startScanningOnLaunch"
                static let manageFamily = "v2.settings.row.manageFamily"
                static let createFamily = "v2.settings.row.createFamily"
                static let aboutMe = "v2.settings.row.aboutMe"
                static let feedback = "v2.settings.row.feedback"
                static let share = "v2.settings.row.share"
                static let tipJar = "v2.settings.row.tipJar"
                static let help = "v2.settings.row.help"
                static let termsOfUse = "v2.settings.row.termsOfUse"
                static let privacyPolicy = "v2.settings.row.privacyPolicy"
            }

            enum Share {
                static let message = "v2.settings.share.message"
            }

            enum Profile {
                static let title = "v2.settings.profile.title"
            }

            enum SignOutConfirm {
                static let title = "v2.settings.signOutConfirm.title"
            }

            enum DeleteConfirm {
                static let title = "v2.settings.deleteConfirm.title"
                static let subtitle = "v2.settings.deleteConfirm.subtitle"
            }

            enum Account {
                static let signInToAvoidLosingData = "v2.settings.account.signInToAvoidLosingData"
                static let signingIn = "v2.settings.account.signingIn"
                static let signInWithApple = "v2.settings.account.signInWithApple"
                static let signInWithGoogle = "v2.settings.account.signInWithGoogle"
            }
        }

        enum FoodNotes {
            static let title = "v2.foodNotes.title"

            enum Validation {
                static let thinking = "v2.foodNotes.validation.thinking"
            }

            enum EmptyState {
                static let title = "v2.foodNotes.empty.title"
                static let tryFollowing = "v2.foodNotes.empty.tryFollowing"
            }
        }

        enum Scan {
            enum Mode {
                static let scan = "v2.scan.mode.scan"
                static let photo = "v2.scan.mode.photo"
            }

            enum Overlay {
                static let alignBarcode = "v2.scan.overlay.alignBarcode"
            }

            enum Status {
                static let submittingPhoto = "v2.scan.status.submittingPhoto"
                static let uploadingPhotoSubtitle = "v2.scan.status.uploadingPhotoSubtitle"
                static let lookingUpProduct = "v2.scan.status.lookingUpProduct"
                static let checkingDatabaseSubtitle = "v2.scan.status.checkingDatabaseSubtitle"
                static let analyzing = "v2.scan.status.analyzing"
            }

            enum Badge {
                static let submitting = "v2.scan.badge.submitting"
                static let fetchingDetails = "v2.scan.badge.fetchingDetails"
            }

            enum Error {
                static let couldNotIdentifyTitle = "v2.scan.error.couldNotIdentify.title"
                static let couldNotIdentifySubtitle = "v2.scan.error.couldNotIdentify.subtitle"
                static let somethingWentWrong = "v2.scan.error.somethingWentWrong"
            }

            enum Permissions {
                static let cameraAccessRequired = "v2.scan.permissions.cameraAccessRequired"
                static let cameraNotAvailableSimulator = "v2.scan.permissions.cameraNotAvailableSimulator"
            }

            enum Callout {
                static let retryOrSwitchToPhoto = "v2.scan.callout.retryOrSwitchToPhoto"
            }
        }

        enum Errors {
            static let genericToast = "v2.errors.generic.toast"
            static let genericSubtitle = "v2.errors.generic.subtitle"

            enum Family {
                static let createFamily = "v2.errors.family.createFamily"
                static let addMember = "v2.errors.family.addMember"
                static let updateMember = "v2.errors.family.updateMember"
            }

            enum Avatar {
                static let upload = "v2.errors.avatar.upload"
                static let save = "v2.errors.avatar.save"
                static let assign = "v2.errors.avatar.assign"
                static let missingName = "v2.errors.avatar.missingName"
            }
        }
    }

    // MARK: - SwiftUI helpers

    static func text(_ key: String) -> Text {
        Text(LocalizedStringKey(key))
    }

    // MARK: - String helpers

    static func string(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    static func formatted(_ key: String, _ args: CVarArg...) -> String {
        String(format: string(key), locale: Locale.current, arguments: args)
    }
}

