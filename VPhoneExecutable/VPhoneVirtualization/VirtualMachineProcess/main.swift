// vphone-vm — the process that actually runs a guest.
//
// This is the only binary in the project signed with the private
// virtualization entitlements (Resources/VPhoneVirtualization.entitlements), and it is
// deliberately the smallest thing that can hold them: it parses the boot
// options, becomes an NSApplication, and hands off to VPhoneVirtualMachineAppDelegate.
// The unentitled vphone-cli starts this process for the boot.
//
// It takes the boot options directly rather than a `boot` subcommand — this
// binary has exactly one job, so there is nothing to select between.

import ArgumentParser
import Foundation
import VPhoneCoreKit
import VPhoneVirtualMachineKit

// This process writes to sockets and pipes whose far end can vanish at any time:
// the guest network's host connections, vphone.sock clients, the camera and
// control channels. A write to a closed one raises SIGPIPE, whose default action
// kills the process and the guest with it. Ignore it once for the whole process
// so every such write fails with EPIPE, which each caller already handles.
signal(SIGPIPE, SIG_IGN)

// A standalone HomeView.app can bind to an existing machine at packaging time.
// Explicit CLI arguments always win; the ordinary VPhone.bundle has no default.
var bootArguments = Array(CommandLine.arguments.dropFirst())
if bootArguments.isEmpty,
   let config = Bundle.main.object(forInfoDictionaryKey: "VPhoneDefaultMachineConfig") as? String,
   !config.isEmpty
{
    bootArguments = [
        "--config", config,
        "--vphoned-bin", VPhoneResources.resolve().vphoned(for: .homeView).path,
    ]
}
VPhoneGuestApp.run(VPhoneBootCommand.parseOrExit(bootArguments))
