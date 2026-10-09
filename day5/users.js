const loadButton = document.getElementById("load-users");
const filterInput = document.getElementById("filter-input");
const statusMessage = document.getElementById("status");
const usersList = document.getElementById("users-list");

const API_URL = "https://jsonplaceholder.typicode.com/users";

let users = [];

async function loadUsers() {
loadButton.disabled = true;
statusMessage.textContent = "Loading users...";
usersList.replaceChildren();

try {
    const response = await fetch(API_URL);

    if (!response.ok) {
        throw new Error(`HTTP error! Status: ${response.status}`);
    }

    users = await response.json();

    renderUsers(getFilteredUsers());

    statusMessage.textContent = `Successfully loaded ${users.length} users.`;
} catch (error) {
    users = [];
    usersList.replaceChildren();

    statusMessage.textContent =
        "Failed to load users. Please check your connection and try again.";

    console.error("Error loading users:", error);
} finally {
    loadButton.disabled = false;
}

}

function renderUsers(list) {
usersList.replaceChildren();

if (list.length === 0) {
    statusMessage.textContent = "No users match your filter.";
    return;
}

const fragment = document.createDocumentFragment();

list.forEach(function (user) {
    const listItem = document.createElement("li");

    const name = document.createElement("h2");
    name.textContent = user.name;

    const email = document.createElement("p");
    email.textContent = `Email: ${user.email}`;

    const city = document.createElement("p");
    city.textContent = `City: ${user.address.city}`;

    const company = document.createElement("p");
    company.textContent = `Company: ${user.company.name}`;

    listItem.append(name, email, city, company);
    fragment.appendChild(listItem);
});

usersList.appendChild(fragment);

}

function getFilteredUsers() {
const searchText = filterInput.value.trim().toLowerCase();

return users.filter(function (user) {
    return user.name.toLowerCase().includes(searchText);
});

}

loadButton.addEventListener("click", loadUsers);

filterInput.addEventListener("input", function () {
if (users.length === 0) {
return;
}

const filteredUsers = getFilteredUsers();

renderUsers(filteredUsers);

if (filteredUsers.length > 0) {
    statusMessage.textContent =
        `Showing ${filteredUsers.length} of ${users.length} users.`;
}

});
