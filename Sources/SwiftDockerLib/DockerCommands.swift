import Foundation
import ShellOut

// MARK: Run & Delete operations

func cleanup(path: String, fileManager: FileManager, silent: Bool = false) {
    if silent == false { printTitle("Removing temporary Dockerfile") }
    try? fileManager.removeItem(atPath: path)
}

func runDockerTests(image: DockerImage, writeDockerFile shouldSaveFile: Bool, rawflags: String?) throws {
    let fileManager = FileManager.default
    let tempDockerFilePath = NSTemporaryDirectory().appending(tempDockerFilePathComponent)

    do {
        cleanup(path: tempDockerFilePath, fileManager: fileManager, silent: true)

        let directoryName = fileManager.currentDirectoryName
        let minimalDockerfile = makeMinimalDockerFile(image: image.imageName, directory: directoryName)

        printTitle("Creating temporary Dockerfile at \(tempDockerFilePath)")
        printBody(minimalDockerfile)
        try minimalDockerfile.write(toFile: tempDockerFilePath, atomically: true, encoding: .utf8)

        let dockerTag = makeDockerTag(forDirectoryName: directoryName, version: image.imageName)

        try runDockerBuild(tag: dockerTag, dockerFilePath: tempDockerFilePath)

        let environment = bashENVFrom(rawflags)
        try runDockerSwiftTest(tag: dockerTag, remove: true, additionalArgs: environment?.args, env: environment?.prefix)

        cleanup(path: tempDockerFilePath, fileManager: fileManager)

        if shouldSaveFile {
            try minimalDockerfile.write(toFile: defaultDockerFilePath, atomically: true, encoding: .utf8)
        }
    } catch {
        cleanup(path: tempDockerFilePath, fileManager: fileManager, silent: true)
        printError(error.localizedDescription)
    }
}

public func runDockerTests(version: String, image: String, writeDockerFile shouldSaveFile: Bool, flags: String?) throws {
    guard let image = DockerImage(version: version, image: image) else { fatalError() }
    try runDockerTests(image: image, writeDockerFile: shouldSaveFile, rawflags: flags)
}

// ENV

func bashENVFrom(_ rawString: String?) -> (prefix: String, args: String)? {
    guard let rawString = rawString else { return nil }
    let components = rawString.components(separatedBy: ",")
    let args = components.flatMap {
        guard let varName = $0.split(separator: "=").first else { return nil }
        return "-e \(varName)"
    }.joined(separator: " ")

    let prefix = components.joined(separator: " ")
    return (prefix, args)
}

// MARK: Shellout wrappers

public func runDockerRemoveImages() throws {
    let startsWithTestPrefix = "^" + dockerImagePrefix
    let remove = ShellOutCommand.dockerRemoveImages(matchingPattern: startsWithTestPrefix)
    try runAndLog(remove, prefix: "Removing images")
}

public func writeDefaultDockerFile(version: String) throws {
    let file = makeMinimalDockerFile(image: makeDefaultImage(forVersion: version), directory: FileManager.default.currentDirectoryName)
    try file.write(toFile: defaultDockerFilePath, atomically: true, encoding: .utf8)
}

func runDockerSwiftTest(tag: String, remove: Bool, additionalArgs: String?, env: String?) throws {
    let testCMD = ShellOutCommand.dockerRun(tag: tag, remove: remove, command: "swift test", additionalArgs: additionalArgs)
    let wrappedCMD = ShellOutCommand.commandWithEnv(env, command: testCMD)
    let cmdWithoutEnv = wrappedCMD.string.components(separatedBy: "docker run").dropFirst().joined()
    try runAndLog(wrappedCMD, prefix: "Running swift test", overideOutput: "docker run \(cmdWithoutEnv)")
}

func runDockerBuild(tag: String, dockerFilePath: String) throws {
    let buildCmd = ShellOutCommand.dockerBuild(tag: tag, dockerFile: dockerFilePath)
    try runAndLog(buildCmd, prefix: "Building docker image")
}
