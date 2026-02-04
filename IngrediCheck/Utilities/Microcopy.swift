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
            static let allow = "v2.common.cta.allow"
            static let allSet = "v2.common.cta.allSet"
            static let back = "v2.common.cta.back"
            static let cancel = "v2.common.cta.cancel"
            static let confirm = "v2.common.cta.confirm"
            static let `continue` = "v2.common.cta.continue"
            static let done = "v2.common.cta.done"
            static let enable = "v2.common.cta.enable"
            static let goToHome = "v2.common.cta.goToHome"
            static let getStarted = "v2.common.cta.getStarted"
            static let gotIt = "v2.common.cta.gotIt"
            static let invite = "v2.common.cta.invite"
            static let maybeLater = "v2.common.cta.maybeLater"
            static let next = "v2.common.cta.next"
            static let notNow = "v2.common.cta.notNow"
            static let ok = "v2.common.cta.ok"
            static let openSettings = "v2.common.cta.openSettings"
            static let save = "v2.common.cta.save"
            static let signOut = "v2.common.cta.signOut"
            static let tryAgain = "v2.common.cta.tryAgain"
            static let viewAll = "v2.common.cta.viewAll"

            enum MatchStatus {
                static let uncertain = "v2.common.matchStatus.uncertain"
                static let matched = "v2.common.matchStatus.matched"
                static let unmatched = "v2.common.matchStatus.unmatched"
                static let unknown = "v2.common.matchStatus.unknown"
                static let analyzing = "v2.common.matchStatus.analyzing"
            }

            enum Value {
                static let notAvailable = "v2.common.value.notAvailable"
            }
        }

        enum Labels {
            static let foodNotes = "v2.common.label.foodNotes"
            static let ingredients = "v2.common.label.ingredients"
            static let chooseAvatar = "v2.common.label.chooseAvatar"
            static let chooseAvatarOptional = "v2.common.label.chooseAvatarOptional"
        }

        enum Validation {
            static let enterName = "v2.common.validation.enterName"
        }

        enum Onboarding {
            enum FoodNotesReady {
                static let title = "v2.onboarding.foodNotesReady.title"
                static let subtitle = "v2.onboarding.foodNotesReady.subtitle"
            }

            enum FineTune {
                static let title = "v2.onboarding.fineTune.title"
                static let subtitle = "v2.onboarding.fineTune.subtitle"
            }

            enum IngrediFamWelcome {
                static let title = "v2.onboarding.ingredifam.welcome.title"
                static let subtitle = "v2.onboarding.ingredifam.welcome.subtitle"
            }

            enum InviteCodePrompt {
                static let title = "v2.onboarding.inviteCodePrompt.title"
                static let subtitle = "v2.onboarding.inviteCodePrompt.subtitle"
                static let ctaEnterInviteCode = "v2.onboarding.inviteCodePrompt.cta.enterInviteCode"
                static let ctaContinueWithoutCode = "v2.onboarding.inviteCodePrompt.cta.continueWithoutCode"
            }

            enum WhosThisFor {
                static let title = "v2.onboarding.whosThisFor.title"
                static let subtitle = "v2.onboarding.whosThisFor.subtitle"
                static let ctaJustMe = "v2.onboarding.whosThisFor.cta.justMe"
                static let ctaAddFamily = "v2.onboarding.whosThisFor.cta.addFamily"
                static let footer = "v2.onboarding.whosThisFor.footer"
            }

            enum ReadyToScan {
                static let title = "v2.onboarding.readyToScan.title"
                static let subtitle = "v2.onboarding.readyToScan.subtitle"
                static let ctaNotRightNow = "v2.onboarding.readyToScan.cta.notRightNow"
                static let ctaHaveAProduct = "v2.onboarding.readyToScan.cta.haveAProduct"
            }

            enum AvatarSetup {
                static let title = "v2.onboarding.avatarSetup.title"
                static let subtitle = "v2.onboarding.avatarSetup.subtitle"
            }

            enum ScanningHelp {
                static let subtitle = "v2.onboarding.scanningHelp.subtitle"
            }

            enum QuickAccessNeeded {
                static let title = "v2.onboarding.quickAccessNeeded.title"
                static let subtitle = "v2.onboarding.quickAccessNeeded.subtitle"
            }

            static let questionPrefix = "v2.onboarding.questionPrefix"
            static let familyMemberSelectNote = "v2.onboarding.familyMemberSelectNote"

            enum ReadyToScanCanvas {
                static let title = "v2.onboarding.readyToScanCanvas.title"
                static let subtitle = "v2.onboarding.readyToScanCanvas.subtitle"
            }

            enum MeetYourProfile {
                static let greetingPrefix = "v2.onboarding.meetYourProfile.greetingPrefix"
                static let greetingSuffix = "v2.onboarding.meetYourProfile.greetingSuffix"
                static let description = "v2.onboarding.meetYourProfile.description"
            }

            enum Dynamic {
                static let unsupportedStepType = "v2.onboarding.dynamic.unsupportedStepType"
                static let otherSelectedNote = "v2.onboarding.dynamic.otherSelectedNote"
            }

            enum FoodNotesSaved {
                static let title = "v2.onboarding.foodNotesSaved.title"
                static let subtitle = "v2.onboarding.foodNotesSaved.subtitle"
            }

            enum JoinFamilyReady {
                static let title = "v2.onboarding.joinFamilyReady.title"
                static let subtitle = "v2.onboarding.joinFamilyReady.subtitle"
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

            enum InvitePrompt {
                static let title = "v2.family.invitePrompt.title"
                static let subtitle = "v2.family.invitePrompt.subtitle"
            }

            enum Setup {
                enum AddMembers {
                    static let title = "v2.family.setup.addMembers.title"
                    static let subtitle = "v2.family.setup.addMembers.subtitle"
                    static let namePlaceholder = "v2.family.setup.addMembers.namePlaceholder"
                    static let ctaAddMember = "v2.family.setup.addMembers.cta.addMember"
                }

                enum WhatsYourName {
                    static let title = "v2.family.setup.whatsYourName.title"
                    static let subtitle = "v2.family.setup.whatsYourName.subtitle"
                    static let namePlaceholder = "v2.family.setup.whatsYourName.namePlaceholder"
                }

                enum MeetYourIngrediFam {
                    static let title = "v2.family.setup.meetYourIngrediFam.title"
                    static let subtitle = "v2.family.setup.meetYourIngrediFam.subtitle"
                }

                enum EditMember {
                    static let title = "v2.family.setup.editMember.title"
                    static let subtitle = "v2.family.setup.editMember.subtitle"
                    static let namePlaceholder = "v2.family.setup.editMember.namePlaceholder"
                }
            }
        }

        enum Auth {
            enum ExistingUser {
                static let title = "v2.auth.existingUser.title"
                static let subtitleLine1 = "v2.auth.existingUser.subtitleLine1"
                static let subtitleLine2 = "v2.auth.existingUser.subtitleLine2"
                static let ctaYesContinue = "v2.auth.existingUser.cta.yesContinue"
                static let ctaNoStartNew = "v2.auth.existingUser.cta.noStartNew"
            }

            enum Provider {
                static let google = "v2.auth.provider.google"
                static let apple = "v2.auth.provider.apple"
            }

            enum WelcomeBack {
                static let title = "v2.auth.welcomeBack.title"
                static let subtitle = "v2.auth.welcomeBack.subtitle"
            }

            static let continueWithGoogle = "v2.auth.cta.continueWithGoogle"
            static let signInLater = "v2.auth.cta.signInLater"

            static let signInToContinueTitle = "v2.auth.signInToContinue.title"
            static let signInToContinueSubtitle = "v2.auth.signInToContinue.subtitle"

            static let signInFailedTitle = "v2.auth.signInFailed.title"
        }

        enum Permissions {
            static let title = "v2.permissions.title"
            static let subtitle = "v2.permissions.subtitle"

            enum AccessDenied {
                static let title = "v2.permissions.accessDenied.title"
                static let subtitle = "v2.permissions.accessDenied.subtitle"
            }

            enum StayUpdated {
                static let title = "v2.permissions.stayUpdated.title"
                static let subtitle = "v2.permissions.stayUpdated.subtitle"
                static let ctaRemindMeLater = "v2.permissions.stayUpdated.cta.remindMeLater"
            }

            enum LetsScanSmarter {
                static let title = "v2.permissions.letsScanSmarter.title"
                static let subtitle = "v2.permissions.letsScanSmarter.subtitle"
            }

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

        enum Insights {
            enum MatchingRate {
                static let title = "v2.insights.matchingRate.title"
                static let emptyHint = "v2.insights.matchingRate.emptyHint"
                static let increasedBy = "v2.insights.matchingRate.increasedBy"
            }

            enum AvgScans {
                static let label = "v2.insights.avgScans.label"
            }

            enum BarcodeScans {
                static let title = "v2.insights.barcodeScans.title"
            }

            enum AllergySummary {
                static let summarizedWithAI = "v2.insights.allergySummary.badge.summarizedWithAI"
                static let emptyBadge = "v2.insights.allergySummary.empty.badge"
                static let emptyDescription = "v2.insights.allergySummary.empty.description"
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

            enum RecentScansFilter {
                static let all = "v2.lists.recentScansFilter.all"
                static let favoritesShort = "v2.lists.recentScansFilter.favoritesShort"
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

            enum MatchStatus {
                enum AlertTitle {
                    static let matched = "v2.product.matchStatus.alertTitle.matched"
                    static let uncertain = "v2.product.matchStatus.alertTitle.uncertain"
                    static let unmatched = "v2.product.matchStatus.alertTitle.unmatched"
                    static let unknown = "v2.product.matchStatus.alertTitle.unknown"
                    static let analyzing = "v2.product.matchStatus.alertTitle.analyzing"
                }
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

            enum CaptureGuide {
                static let title = "v2.scan.captureGuide.title"
                static let footer = "v2.scan.captureGuide.footer"

                static let introDescription = "v2.scan.captureGuide.intro.description"

                enum Front {
                    static let prefix = "v2.scan.captureGuide.front.prefix"
                    static let keyword = "v2.scan.captureGuide.front.keyword"
                    static let suffix = "v2.scan.captureGuide.front.suffix"
                }

                enum Back {
                    static let prefix = "v2.scan.captureGuide.back.prefix"
                    static let keyword = "v2.scan.captureGuide.back.keyword"
                    static let suffix = "v2.scan.captureGuide.back.suffix"
                }

                enum NutritionFacts {
                    static let prefix = "v2.scan.captureGuide.nutritionFacts.prefix"
                    static let keyword = "v2.scan.captureGuide.nutritionFacts.keyword"
                    static let suffix = "v2.scan.captureGuide.nutritionFacts.suffix"
                }

                enum IngredientsList {
                    static let prefix = "v2.scan.captureGuide.ingredientsList.prefix"
                    static let keyword = "v2.scan.captureGuide.ingredientsList.keyword"
                    static let suffix = "v2.scan.captureGuide.ingredientsList.suffix"
                }
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

        enum Chat {
            static let inputPlaceholder = "v2.chat.input.placeholder"
            static let ctaAskIngrediBot = "v2.chat.cta.askIngrediBot"
            static let ctaCopyText = "v2.chat.cta.copyText"
            static let feedbackPromptMessage = "v2.chat.feedbackPrompt.message"

            enum IngrediBotIntro {
                static let greetingPrefix = "v2.chat.ingredibot.greetingPrefix"
                static let name = "v2.chat.ingredibot.name"

                static let title = "v2.chat.ingredibot.title"
                static let question = "v2.chat.ingredibot.question"

                enum OtherSelected {
                    static let prefix = "v2.chat.ingredibot.otherSelected.prefix"
                    static let keyword = "v2.chat.ingredibot.otherSelected.keyword"
                    static let suffix = "v2.chat.ingredibot.otherSelected.suffix"
                }

                static let prompt = "v2.chat.ingredibot.prompt"
                static let ctaYesLetsGo = "v2.chat.ingredibot.cta.yesLetsGo"
                static let footer = "v2.chat.ingredibot.footer"
            }
        }

        enum Tutorial {
            static let swipeCardsHint = "v2.tutorial.swipeCardsHint"

            enum RedactedCard {
                static let title = "v2.tutorial.redactedCard.title"
                static let subtitle = "v2.tutorial.redactedCard.subtitle"
            }
        }

        enum Avatar {
            enum CreateCard {
                static let title = "v2.avatar.createCard.title"
                static let subtitle = "v2.avatar.createCard.subtitle"
                static let ctaExplore = "v2.avatar.createCard.ctaExplore"
            }

            enum Current {
                static let message = "v2.avatar.current.message"
                static let ctaCreateNew = "v2.avatar.current.cta.createNew"
            }

            enum Generate {
                static let title = "v2.avatar.generate.title"
                static let selected = "v2.avatar.generate.selected"
            }

            enum Update {
                static let title = "v2.avatar.update.title"
                static let subtitle = "v2.avatar.update.subtitle"
                static let hint = "v2.avatar.update.hint"
            }
        }

        enum Disclaimer {
            static let title = "v2.disclaimer.title"
            static let body = "v2.disclaimer.body"
            static let ctaUnderstand = "v2.disclaimer.cta.understand"
        }

        enum Feedback {
            enum Card {
                static let titleLine1 = "v2.feedback.card.title.line1"
                static let titleLine2 = "v2.feedback.card.title.line2"
                static let titleLine3 = "v2.feedback.card.title.line3"
                static let subtitle = "v2.feedback.card.subtitle"
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

