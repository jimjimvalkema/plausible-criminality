import { hashAddress } from "../scripts/hashor"

export function setEventHandlers() {
    const generateAddressBtn = document.getElementById("generateNewAddress")
    generateAddressBtn.addEventListener("click", async ()=>generateAddressHandler())

}

function generateAddressHandler() {

}