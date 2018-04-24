import ShellOut

extension ShellOutCommand {
    static func dockerBuildCurrentDirectory(tag: String) -> ShellOutCommand {
        return dockerBuild(tag: tag, dockerFile: ".")
    }

    static func dockerBuild(tag: String, dockerFile: String) -> ShellOutCommand {
        let file = dockerFile == "." ? dockerFile : "--file \(dockerFile)"
        let dockerBuild = "docker build -t \(tag) . \(file)"
        return ShellOutCommand(string: dockerBuild)
    }

    static func dockerRun(tag: String, remove: Bool, command: String, additionalArgs: String? = nil) -> ShellOutCommand {
        let removeTag = remove ? "--rm" : ""
        let args: String = additionalArgs ?? ""
        let dockerRun = "docker run \(removeTag) \(args) \(tag) \(command)"
        return ShellOutCommand(string: dockerRun)
    }

    static func dockerRemoveImages(matchingPattern pattern: String) -> ShellOutCommand {
        let removeImages = "docker images -a | grep \"\(pattern)\" | awk '{print $3}' | xargs docker rmi"
        return ShellOutCommand(string: removeImages)
    }

    static func commandWithEnv(_ env: String?, command: ShellOutCommand) -> ShellOutCommand {
        let prefix = env ?? ""
        return ShellOutCommand(string: "\(prefix) \(command.string)")
    }
}
