import { ArgumentParser } from 'argparse';
import fs from "fs/promises";


async function lineReplacer(filePath, lineReplacements) {
    const file = await fs.open(filePath, "r")
    let newFile = ""

    for await (const line of file.readLines()) {
        //if (line.startsWith("contract HonkVerifier is IVerifier")) {  
        const replacement = lineReplacements.find((replacement) => line.startsWith(replacement.original))
        if (replacement) {
            newFile += replacement.replacement + "\n"
            console.log({ replacement })
        } else {
            newFile += line + "\n"
        }
    }
    await file.close()
    await fs.writeFile(filePath, newFile);
}




async function main() {
    const parser = new ArgumentParser({
        description: 'Argparse example',
        usage: `quick lil script to replace 1 line`
    });
    console.log(parser)

    parser.add_argument('-f', '--file', { help: 'file to read', required: true, type: 'str' });
    parser.add_argument('-r', '--remove', { help: 'specify what line to replace', required: true, type: 'str' });
    parser.add_argument('-p', '--replace', { help: 'specify what to replace it with', required: true, type: 'str' });
    const args = parser.parse_args() 

    const lineReplacements = [
        {
            "original"      :args.remove,
            "replacement"   :args.replace
        }
    ]
    await lineReplacer(args.file, lineReplacements)


}

await main()