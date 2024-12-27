let debug = false; // Прапор для виведення повідомлень у консоль
let translations = {};
let currentLanguage = 'en'; // Поточна мова

// Завантаження перекладів
    function loadTranslations(language, callback) {
        fetch('translations.json')
            .then(response => response.json())
            .then(data => {
                translations = data[language] || {};
                if (debug) console.log('Translations loaded:', translations);
                if (callback) callback();
            })
            .catch(error => {
                if (debug) console.error('Error loading translations:', error);
            });
    }

// Виклик завантаження мови при завантаженні сторінки
    document.addEventListener('DOMContentLoaded', () => {
        loadTranslations(currentLanguage, () => {
            if (debug) console.log(`Language set to: ${currentLanguage}`);
        });
    });



    // Івенти
    document.addEventListener('DOMContentLoaded', () => {
        const eventMenuItem = document.querySelector('.menu-item[data-target="events"]');
        const eventContainer = document.querySelector('#events .event-list'); // Контейнер для івентів

        if (!eventMenuItem) {
            if (debug) console.error(translations['eventMenuNotFound']);
            return;
        }
        if (!eventContainer) {
            if (debug) console.error(translations['eventContainerNotFound']);
            return;
        }

        function loadEvents() {
            if (debug) console.log(translations['eventFetchRequest']);
            fetch(`https://${GetParentResourceName()}/getEventList`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json; charset=UTF-8',
                },
                body: JSON.stringify({})
            })
                .then(response => {
                    if (debug) console.log(`${translations['eventFetchResponse']}: ${response.status}`);
                    if (!response.ok) {
                        throw new Error(`${translations['httpError']} ${response.status}`);
                    }
                    return response.json();
                })
                .then(events => {
                    if (debug) console.log(translations['eventFetchSuccess'], events);
                    renderEvents(events);
                })
                .catch(err => {
                    if (debug) console.error(`${translations['eventFetchError']}:`, err);
                });
        }

        function renderEvents(events) {
            eventContainer.innerHTML = ''; // Очищуємо попередній вміст

            if (events.length === 0) {
                eventContainer.innerHTML = `<p>${translations['noAvailableEvents']}</p>`;
                return;
            }

            const currentEventsContainer = document.createElement('div');
            currentEventsContainer.classList.add('current-events'); // Додаємо клас для поточних івентів

            const otherEventsContainer = document.createElement('div');
            otherEventsContainer.classList.add('event-container'); // Додаємо клас для загального гріду

            const divider = document.createElement('div');
            divider.classList.add('divider'); // Додаємо клас Divider

            let missingImagesLogged = false; // Флаг для одноразового логування

            events.forEach((event, index) => {
                const eventCard = document.createElement('div');
                eventCard.classList.add('event-card');

                const thumbnailPath = event.Thumbnail; // Використовуємо шлях, наданий у властивості
                eventCard.innerHTML = `
                    <div class="event-thumbnail">
                        <img src="${thumbnailPath}" alt="${event.Title}">
                    </div>
                    <div class="event-details">
                        <h3>${event.Title}</h3>
                        <p>${event.ShortDescription}</p>
                        <div class="event-meta">
                            <span class="event-date">${event.DateTime}</span>
                            <span class="event-location">${event.Location}</span>
                        </div>
                        <button class="event-more" data-id="${event.ID}">${translations['eventMoreButton']}</button>
                    </div>
                `;

                const imageElement = eventCard.querySelector('.event-thumbnail img');
                imageElement.onerror = () => {
                    if (!missingImagesLogged) {
                        if (debug) console.error(`${translations['missingEventImages']} ${thumbnailPath}`);
                        missingImagesLogged = true; // Логування виконується лише один раз
                    }
                    imageElement.src = '/img/default.jpg'; // Заміна на стандартне зображення
                };

                eventCard.querySelector('.event-more').addEventListener('click', () => {
                    showEventDetails(event);
                });

                if (index < 2) {
                    currentEventsContainer.appendChild(eventCard);
                } else {
                    otherEventsContainer.appendChild(eventCard);
                }
            });

            eventContainer.appendChild(currentEventsContainer);
            eventContainer.appendChild(divider);
            eventContainer.appendChild(otherEventsContainer);
        }

        function showEventDetails(event) {
            if (!event) {
                if (debug) console.error(translations['eventNotFound']);
                return;
            }

            const modal = document.createElement('div');
            modal.classList.add('event-modal');
            modal.innerHTML = `
                <div class="modal-content">
                    <button class="modal-close">✖</button>
                    <h2>${event.Title || translations['noEventTitle']}</h2>
                    <img src="${event.Image || ''}" alt="${event.Title || translations['defaultImageAlt']}" class="event-image">
                    <p>${event.FullDescription || translations['noEventDescription']}</p>
                    <div class="event-meta">
                        <strong>${translations['eventDateTime']}</strong> ${event.DateTime || translations['notSpecified']}<br>
                        <strong>${translations['eventLocation']}</strong> ${event.Location || translations['notSpecified']}<br>
                        <strong>${translations['eventOrganizer']}</strong> ${event.Organizer || translations['notSpecified']}
                    </div>
                </div>
            `;

            modal.querySelector('.modal-close').addEventListener('click', () => {
                modal.remove();
            });

            modal.addEventListener('click', (e) => {
                if (e.target === modal) {
                    modal.remove();
                }
            });

            modal.addEventListener('contextmenu', (e) => {
                e.preventDefault();
                modal.remove();
            });

            document.body.appendChild(modal);
        }

        eventMenuItem.addEventListener('click', () => {
            if (debug) console.log(translations['eventMenuClicked']);
            loadEvents();
        });
    });




    // Запит інформації про гравця під час відкриття UI
    function requestPlayerInfo() {
        fetch(`https://${GetParentResourceName()}/requestPlayerInfo`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
        })
            .then(resp => resp.json())
            .then(data => {
                if (debug) console.log('Отримано дані профілю:', data);
                updateProfileInfo(data.firstName, data.lastName, data.job);
            })
            .catch(error => {
                console.error('Помилка при запиті інформації про гравця:', error);
            });
    }

    // Сайдбар
    document.addEventListener('DOMContentLoaded', () => {
        const profileNameElement = document.getElementById('profile-name');
        const profileJobElement = document.getElementById('profile-job');

        // Функція для оновлення інформації профілю
        function updateProfileInfo(data) {
            if (data.firstName && data.lastName) {
                profileNameElement.textContent = `${data.firstName} ${data.lastName}`;
            } else {
                profileNameElement.textContent = 'Безіменний';
            }

            if (data.job) {
                profileJobElement.textContent = data.job;
            } else {
                profileJobElement.textContent = 'Безробітний';
            }
        }

        // Обробка повідомлень від клієнта
        window.addEventListener('message', (event) => {
            if (event.data.type === 'updatePlayerInfo') {
                console.log('Отримано інформацію профілю:', event.data.payload);
                updateProfileInfo(event.data.payload);
            }
        });
    });

    // Сайдбар
    document.addEventListener('DOMContentLoaded', () => {
        const uiContainer = document.getElementById('ui-container');
        const sidebar = document.querySelector('.sidebar');
        const mainContent = document.querySelector('.main-content');
    
        const setEqualHeight = () => {
            const containerHeight = uiContainer.offsetHeight;
            sidebar.style.height = `${containerHeight}px`;
            mainContent.style.height = `${containerHeight}px`;
        };
    
        setEqualHeight();
    
        window.addEventListener('resize', setEqualHeight);
    
        const menuItems = document.querySelectorAll('.menu-item');
        const contentPanels = document.querySelectorAll('.content-panel');
        const profileButton = document.querySelector('.profile-button');
        const settingsArrow = document.getElementById('settings-arrow');
        const settingsDropdown = document.getElementById('settings-dropdown');
        const dropdownItems = document.querySelectorAll('.dropdown-item');
    
        menuItems.forEach(item => {
            item.addEventListener('click', (event) => {
                event.stopPropagation();
                const targetId = item.getAttribute('data-target');
    
                contentPanels.forEach(panel => {
                    panel.classList.remove('active');
                    if (panel.id === targetId) {
                        panel.classList.add('active');
                    }
                });
    
                menuItems.forEach(menu => {
                    menu.classList.remove('active');
                });
                item.classList.add('active');
    
                if (targetId === 'shop') {
                    fetch(`https://${GetParentResourceName()}/chatCommand`, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json; charset=UTF-8',
                        },
                        body: JSON.stringify({
                            command: '/battlepass'
                        })
                    }).then(resp => resp.json()).then(resp => {
                        if (debug) console.log(translations['chatCommandSuccess'], resp);
                    }).catch(error => {
                        if (debug) console.error(translations['chatCommandError'], error);
                    });
                }
    
                if (!item.classList.contains('settings-menu')) {
                    settingsDropdown.classList.remove('show');
                }
            });
        });
    
        dropdownItems.forEach(item => {
            item.addEventListener('click', (event) => {
                event.stopPropagation();
                const targetId = item.getAttribute('data-target');
    
                contentPanels.forEach(panel => {
                    panel.classList.remove('active');
                    if (panel.id === targetId) {
                        panel.classList.add('active');
                    }
                });
    
                settingsDropdown.classList.remove('show');
            });
        });
    
        profileButton.addEventListener('click', () => {
            contentPanels.forEach(panel => {
                panel.classList.remove('active');
            });
            document.getElementById('stats').classList.add('active');
    
            profileButton.classList.add('active');
            if (debug) console.log(translations['profileButtonClicked']);
            displayPlayerSkills();
        });
    
        settingsArrow.addEventListener('click', (event) => {
            event.stopPropagation();
            settingsDropdown.classList.toggle('show');
        });
    
        document.addEventListener('click', (event) => {
            if (!settingsDropdown.contains(event.target) && event.target !== settingsArrow) {
                settingsDropdown.classList.remove('show');
            }
        });
    
        window.addEventListener('message', (event) => {
            if (debug) console.log(translations['messageReceived'], event.data);
    
            if (event.data.type === 'open') {
                uiContainer.style.display = 'flex';
                sidebar.style.display = 'flex';
                mainContent.style.display = 'block';
                if (debug) console.log(translations['uiOpened'], event.data.target);
    
                setEqualHeight();
                requestPlayerInfo();
                loadEvents();
            } else if (event.data.type === 'close') {
                uiContainer.style.display = 'none';
                sidebar.style.display = 'none';
                mainContent.style.display = 'none';
                if (debug) console.log(translations['uiClosed']);
            }
        });

        window.addEventListener('message', (event) => {
            if (debug) console.log(translations['messageReceived'], event.data);
        
            if (event.data.type === 'open') {
                uiContainer.style.display = 'flex';
                sidebar.style.display = 'flex';
                mainContent.style.display = 'block';
                if (debug) console.log(translations['uiOpened'], event.data.target);
        
                setEqualHeight();
        
                // Оновлення імені та роботи гравця
                if (event.data.firstName && event.data.lastName && event.data.job) {
                    updateProfileInfo(event.data.firstName, event.data.lastName, event.data.job);
                }
        
                loadEvents();
            } else if (event.data.type === 'close') {
                uiContainer.style.display = 'none';
                sidebar.style.display = 'none';
                mainContent.style.display = 'none';
                if (debug) console.log(translations['uiClosed']);
            }
        });
        
    
        document.addEventListener('keydown', (event) => {
            if (event.key === 'Escape') {
                fetch(`https://${GetParentResourceName()}/hide_ui`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json; charset=UTF-8',
                    },
                    body: JSON.stringify({})
                }).then(resp => resp.json()).then(resp => {
                    if (debug) console.log(translations['uiClosedByEscape']);
                }).catch(error => {
                    if (debug) console.error(translations['uiCloseError'], error);
                });
            }
        });
    });
    

    // Skills Page
    document.addEventListener('DOMContentLoaded', () => {
        const profileButton = document.querySelector('.profile-button');

        profileButton.addEventListener('click', () => {
            if (debug) console.log(translations['profileButtonClicked']);
            fetchPlayerSkills(); // Виклик функції для запиту даних з сервера
        });
        
        function fetchPlayerSkills() {
            if (debug) console.log(translations['fetchPlayerSkillsStart']);
            fetch(`https://${GetParentResourceName()}/requestPlayerSkills`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json; charset=UTF-8',
                },
                body: JSON.stringify({})
            })
                .then(resp => resp.json())
                .then(playerData => {
                    if (debug) console.log(translations['fetchPlayerSkillsSuccess']);
                    displayPlayerSkills(playerData);
                })
                .catch(error => {
                    if (debug) console.error(translations['fetchPlayerSkillsError'], error);
                });
        }
        
        window.addEventListener('message', (event) => {
            if (event.data.type === 'updatePlayerSkills') {
                if (debug) console.log(translations['updatePlayerSkillsReceived']);
                displayPlayerSkills(event.data.payload);
            }
        });
        

        function updateProgressBar(progress) {
            const circle = document.querySelector('.progress-ring__circle');
            const radius = circle.r.baseVal.value;
            const circumference = 2 * Math.PI * radius;

            circle.style.strokeDasharray = `${circumference} ${circumference}`;
            circle.style.strokeDashoffset = `${circumference}`;

            const offset = circumference - (progress / 100) * circumference;
            circle.style.strokeDashoffset = offset;

            document.querySelector('.progress-text').textContent = `${progress}%`;
        }

        function displayPlayerSkills(playerData) {
            if (debug) console.log(translations['displayPlayerSkillsStart'], playerData);
        
            const { LevelColumns, ExpNeededForEarnLVL, SkillData } = playerData;
        
            if (!LevelColumns || typeof LevelColumns !== 'object') {
                if (debug) console.error(translations['errorInvalidLevelColumns']);
                return;
            }
        
            if (!ExpNeededForEarnLVL || typeof ExpNeededForEarnLVL !== 'object') {
                if (debug) console.error(translations['errorInvalidExpNeeded']);
                return;
            }
        
            fetch(`https://${GetParentResourceName()}/requestSettings`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json; charset=UTF-8',
                },
            })
                .then((resp) => resp.json())
                .then((settings) => {
                    const viewType = settings.levelgrid || 'rows';
                    const skillsContainer = document.querySelector('.playerstats-skills-container');
                    const tableHeader = document.querySelector('.playerstats-table thead');
        
                    // Перевіряємо тип відображення
                    if (viewType === 'grid') {
                        tableHeader.style.display = 'none'; // Ховаємо заголовок таблиці
                        skillsContainer.classList.add('grid-view');
                        skillsContainer.classList.remove('rows-view');
                    } else {
                        tableHeader.style.display = ''; // Повертаємо заголовок таблиці
                        skillsContainer.classList.add('rows-view');
                        skillsContainer.classList.remove('grid-view');
                    }
        
                    const playerSkills = Object.keys(LevelColumns).map((skillKey) => {
                        const skillKeyWithLvl = `${skillKey}_lvl`;
                        const skillInfo = SkillData?.[skillKey] || { skill: skillKey, icon: 'default.svg' };
                        const level = playerData[LevelColumns[skillKey]?.lvl] ?? translations['unknownLevel'];
                        const xp = playerData[LevelColumns[skillKey]?.xp] ?? 0;
        
                        const currentLvlXp = ExpNeededForEarnLVL?.[skillKeyWithLvl]?.[level] ?? 0;
                        const nextLvlXp = ExpNeededForEarnLVL?.[skillKeyWithLvl]?.[level + 1] ?? translations['notAvailable'];
        
                        let progress = 0;
                        if (nextLvlXp !== translations['notAvailable'] && nextLvlXp - currentLvlXp > 0) {
                            progress = ((xp - currentLvlXp) / (nextLvlXp - currentLvlXp)) * 100;
                        }
        
                        return {
                            skill: skillInfo.skill || skillKey.charAt(0).toUpperCase() + skillKey.slice(1),
                            level: level,
                            xp: xp,
                            currentLvlXp: currentLvlXp,
                            nextLvlXp: nextLvlXp,
                            progress: Math.min(Math.max(progress, 0), 100),
                            icon: skillInfo.icon || `${skillKey}.svg`,
                            description: skillInfo.description || [],
                        };
                    });
        
                    skillsContainer.innerHTML = '';
        
                    if (viewType === 'grid') {
                        playerSkills.forEach((skillData) => {
                            const skillCard = document.createElement('div');
                            skillCard.className = 'playerstats-skill-card';
        
                            skillCard.innerHTML = `
                                <img src="img/playerstats/${skillData.icon}" alt="${translations['skillIconAlt']}" class="playerstats-skill-icon">
                                <span class="playerstats-skill-name">${skillData.skill}</span>
                                <span class="playerstats-skill-level">${translations['level']}: ${skillData.level}</span>
                                <span class="playerstats-skill-exp">${skillData.xp} / ${skillData.nextLvlXp}</span>
                                <div class="playerstats-progress-bar">
                                    <div class="playerstats-progress" style="width: ${skillData.progress}%;"></div>
                                </div>
                            `;
        
                            skillCard.addEventListener('click', () => openSkillDetails(skillData));
        
                            skillsContainer.appendChild(skillCard);
                        });
                    } else {
                        playerSkills.forEach((skillData) => {
                            const skillRow = document.createElement('tr');
        
                            skillRow.innerHTML = `
                                <td class="playerstats-skill">
                                    <img src="img/playerstats/${skillData.icon}" alt="${translations['skillIconAlt']}" class="playerstats-skill-icon">
                                    <span class="playerstats-skill-name">${skillData.skill}</span>
                                </td>
                                <td class="playerstats-skill-level">${skillData.level}</td>
                                <td class="playerstats-skill-exp">${skillData.xp} / ${skillData.nextLvlXp}</td>
                                <td class="playerstats-progress-bar-cell">
                                    <div class="playerstats-progress-bar">
                                        <div class="playerstats-progress" style="width: ${skillData.progress}%;"></div>
                                    </div>
                                </td>
                            `;
        
                            skillRow.addEventListener('click', () => openSkillDetails(skillData));
        
                            skillsContainer.appendChild(skillRow);
                        });
                    }
                })
                .catch((error) => {
                    if (debug) console.error(translations['errorLoadingViewType'], error);
                });
        }
        


        // Функція для відображення модального вікна
        function openSkillDetails(skillData) {
            const modal = document.getElementById('skill-details-modal');
            const modalBody = document.querySelector('.skill-modal-body');
            const modalTitle = document.getElementById('skill-title');

            // Оновлення заголовку модального вікна
            modalTitle.textContent = skillData.skill;

            // Генерація основного контенту
            const contentHTML = skillData.description
                .map(desc => {
                    if (desc.type === "imageGrid") {
                        // Генерація гріду зображень
                        return `
                            <div class="skill-modal-image-grid">
                                ${desc.images
                                    .map(image => `<img src="${image}" class="grid-image" alt="Skill Image">`)
                                    .join('')}
                            </div>
                        `;
                    } else if (desc.type === "imageSlider") {
                        // Генерація слайдера зображень
                        return `
                            <div class="skill-modal-image-slider">
                                <div class="slider-wrapper">
                                    ${desc.images
                                        .map(image => `<div class="skill-modal-slider-slide"><img src="${image}" alt="Skill Slider Image"></div>`)
                                        .join('')}
                                </div>
                                <button class="skill-modal-slider-prev">&lt;</button>
                                <button class="skill-modal-slider-next">&gt;</button>
                            </div>
                        `;
                    } else {
                        // Генерація основного тексту та зображень
                        return `
                            ${desc.title ? `<h3>${desc.title}</h3>` : ''}
                            ${desc.subtitle ? `<h4>${desc.subtitle}</h4>` : ''}
                            ${desc.text ? `<p>${desc.text}</p>` : ''}
                            ${desc.image ? `<img src="${desc.image}" alt="${desc.title || skillData.skill}" class="skill-detail-image">` : ''}
                        `;
                    }
                })
                .join('');

            // Додавання контенту в модальне вікно
            modalBody.innerHTML = contentHTML;
            modal.style.display = 'block';

            // Ініціалізація слайдера
            const sliders = document.querySelectorAll('.skill-modal-image-slider');
            sliders.forEach(slider => initializeSlider(slider));

            document.getElementById('skill-details-close').addEventListener('click', () => {
                modal.style.display = 'none';
            });

            window.addEventListener('click', (e) => {
                if (e.target === modal) {
                    modal.style.display = 'none';
                }
            });
        }

        // Ініціалізація слайдера з фіксованим розміром
        function initializeSlider(sliderContainer) {
            const slides = sliderContainer.querySelectorAll('.skill-modal-slider-slide');
            const prevButton = sliderContainer.querySelector('.skill-modal-slider-prev');
            const nextButton = sliderContainer.querySelector('.skill-modal-slider-next');
            let currentIndex = 0;

            // Оновлюємо слайди
            const updateSlider = () => {
                slides.forEach((slide, index) => {
                    slide.classList.toggle('active', index === currentIndex);
                });
            };

            // Перемикання слайдів
            prevButton.addEventListener('click', () => {
                currentIndex = (currentIndex - 1 + slides.length) % slides.length;
                updateSlider();
            });

            nextButton.addEventListener('click', () => {
                currentIndex = (currentIndex + 1) % slides.length;
                updateSlider();
            });

            updateSlider();
        }

        // Ініціалізація всіх слайдерів
        function initializeAllSliders() {
            const sliders = document.querySelectorAll('.skill-modal-image-slider');
            sliders.forEach(slider => initializeSlider(slider));
        }

        // Функція для відображення/приховування слайдера
        function toggleSliderVisibility(sliderContainer, show) {
            if (show) {
                sliderContainer.classList.remove('hide');
            } else {
                sliderContainer.classList.add('hide');
            }
        }

        // Виклик функції для ініціалізації всіх слайдерів
        initializeAllSliders();

        // Приклад використання toggleSliderVisibility
        // Передаємо `true` для відображення слайдера або `false` для приховування
        const exampleSlider = document.querySelector('.skill-modal-image-slider');
        toggleSliderVisibility(exampleSlider, true); // Показуємо слайдер


        // Викликаємо функцію для завантаження даних одразу при завантаженні сторінки
        fetchPlayerSkills();
    });


    // Сторінка Ачівок

    document.addEventListener('DOMContentLoaded', () => {
        const achievementsGrid = document.querySelector('.achievements-grid');

        // Функція для відображення ачівок
        function displayAchievements(achievements) {
            // Очищуємо грід перед додаванням нових даних
            achievementsGrid.innerHTML = '';

            if (!achievements || Object.keys(achievements).length === 0) {
                const noAchievementsMessage = document.createElement('p');
                noAchievementsMessage.textContent = 'У вас ще немає ачівок. Виконуйте завдання, щоб їх отримати!';
                noAchievementsMessage.classList.add('no-achievements-message');
                achievementsGrid.appendChild(noAchievementsMessage);
                return;
            }

            // Логування структури ачівок для діагностики
            console.log('Achievements structure:', JSON.stringify(achievements, null, 2));

            // Додаємо кожну ачівку до гріду
            Object.values(achievements).forEach((achievement) => {
                const achievementCard = document.createElement('div');
                achievementCard.classList.add('achievement-card');

                // Перевірка, чи є необхідні поля
                if (!achievement.icon || !achievement.title || !achievement.achievedAt) {
                    console.error('Пропущені поля у досягненні:', achievement);
                    return;
                }

                achievementCard.innerHTML = `
                <div class="achievement-image">
                    <img src="img/achivments/${achievement.icon}" alt="${achievement.title}" 
                        onerror="this.src='img/achivments/default.svg';">
                </div>
                <div class="achievement-info">
                    <h3>${achievement.title}</h3>
                    <p>${achievement.description || 'Опис відсутній'}</p>
                    <p>Отримано: ${new Date(achievement.achievedAt * 1000).toLocaleDateString()}</p>
                </div>
            `;
            

                achievementsGrid.appendChild(achievementCard);
            });
        }


        // Обробка події, коли сервер надсилає ачівки
        window.addEventListener('message', (event) => {
            if (event.data.type === 'updatePlayerSkills' && event.data.achievements) {
                console.log('Отримано ачівки:', JSON.stringify(event.data.achievements, null, 2)); // Логування структури
                displayAchievements(event.data.achievements);
            }
        });
        

        // Функція для запиту ачівок через NUI
        function requestAchievements() {
            fetch(`https://${GetParentResourceName()}/requestPlayerSkills`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json; charset=UTF-8',
                },
                body: JSON.stringify({})
            })
            .then((resp) => resp.json())
            .then((data) => {
                if (data.achievements) {
                    displayAchievements(data.achievements);
                } else {
                    console.error('Помилка: ачівки не знайдено у відповіді сервера.', data);
                }
            })
            .catch((error) => {
                console.error('Помилка при запиті ачівок:', error);
            });
        }

        // Додаємо обробник для перемикання на сторінку ачівок
        const achievementsMenuItem = document.querySelector('.menu-item[data-target="achievements"]');
        if (achievementsMenuItem) {
            achievementsMenuItem.addEventListener('click', () => {
                if (debug) console.log('Перехід на сторінку ачівок');
                requestAchievements();
            });
        }
    });


    // Сторінка Загальних налаштувань
    document.addEventListener('DOMContentLoaded', () => {
        const saveButton = document.getElementById('save-settings');
        const themeRadios = document.querySelectorAll('input[name="theme"]');
        const levelgridRadios = document.querySelectorAll('input[name="levelgrid"]');
        const notificationAlert = document.getElementById('notification-container');

        // Ініціалізація теми
        function initializeTheme() {
            document.body.classList.add('theme-default'); // Встановлюємо нейтральну тему за замовчуванням
        }

        // Застосовуємо тему до сторінки
        function applyTheme(theme) {
            document.body.className = ''; // Скидаємо всі теми
            document.body.classList.add(`theme-${theme}`);
        }

        // Запит налаштувань через NUI Callback
        function fetchSettings() {
            fetch(`https://${GetParentResourceName()}/requestSettings`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json; charset=UTF-8',
                },
            })
                .then((resp) => resp.json())
                .then((settings) => {
                    if (debug) console.log(translations['settingsFetched'], settings);
                    if (settings) {
                        // Встановлюємо обрану тему
                        themeRadios.forEach(radio => {
                            radio.checked = radio.value === settings.theme;
                        });

                        applyTheme(settings.theme); // Застосовуємо тему

                        // Встановлюємо обраний тип сітки
                        levelgridRadios.forEach(radio => {
                            radio.checked = radio.value === settings.levelgrid;
                        });
                    }
                })
                .catch((error) => {
                    if (debug) console.error(translations['errorFetchingSettings'], error);
                });
        }

        // Збереження налаштувань через NUI Callback
        saveButton.addEventListener('click', () => {
            const selectedTheme = [...themeRadios].find(radio => radio.checked)?.value || 'light';
            const selectedLevelgrid = [...levelgridRadios].find(radio => radio.checked)?.value || 'grid';
        
            const settings = {
                theme: selectedTheme,
                levelgrid: selectedLevelgrid,
            };
        
            fetch(`https://${GetParentResourceName()}/saveSettings`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json; charset=UTF-8',
                },
                body: JSON.stringify(settings),
            })
                .then((resp) => resp.json())
                .then((result) => {
                    if (debug) console.log(translations['settingsSaved'], result);
                    applyTheme(selectedTheme); // Застосовуємо тему
                    showSettingsNotification(translations['settingsSavedSuccess'], true); // Використовуємо нову функцію
                })
                .catch((error) => {
                    if (debug) console.error(translations['errorSavingSettings'], error);
                    showSettingsNotification(translations['settingsSavedError'], false); // Використовуємо нову функцію
                });
        });
        

        initializeTheme(); // Ініціалізуємо нейтральну тему
        fetchSettings(); // Викликаємо при завантаженні сторінки
    });


    // Scroling Bar
    document.addEventListener('DOMContentLoaded', () => {
        const mainContent = document.querySelector('.main-content');

        // Стилізуємо скрол бар, додаючи клас для custom стилів
        mainContent.classList.add('custom-scrollbar');

        // Додаємо необхідні стилі через JavaScript (якщо потрібно)
        mainContent.style.scrollbarWidth = 'thin'; // Для Firefox
        mainContent.style.scrollbarColor = '#343a40 #f8f9fa'; // Для Firefox
    });

    // EXP notification
    document.addEventListener('DOMContentLoaded', () => {
        window.addEventListener('message', (event) => {
            if (event.data.action === 'updateExperience') {
                console.log('Received updateExperience data:', event.data); // Лог для перевірки
                showNotification(event.data);
            }
        });
    });


let notificationCount = 0;
const notificationQueue = [];
const MAX_NOTIFICATIONS = 10;

    function loadNotificationHTML(callback) {
        const notificationHTML = `
            <div class="SkillNotificationMarkoScripts">
                <div class="Header">
                    <div class="Rectangle34">${translations['notification.xp']}</div>
                    <div class="SkillName">${translations['notification.skillName']}</div>
                    <div class="XmAgo">${translations['notification.justNow']}</div>
                </div>
                <div class="MetaData">
                    <div class="TitleDescPic">
                        <div class="TitleDesc">
                            <div class="Title"></div>
                            <div class="Description"></div>
                        </div>
                        <div class="Pic"></div>
                    </div>
                    <div class="Notification">
                        <div class="AdditionalNotificationCount"></div>
                    </div>
                </div>
            </div>
        `;
        const template = document.createElement('template');
        template.innerHTML = notificationHTML.trim();
        callback(template.content.firstChild);
    }

// Функція для показу сповіщення про збереження налаштувань
    function showSettingsNotification(message, isSuccess) {
        // Створюємо новий елемент сповіщення
        const notification = document.createElement('div');
        notification.className = 'notification-alert';
        notification.textContent = message;

        // Додаємо клас залежно від типу сповіщення
        if (isSuccess) {
            notification.style.backgroundColor = '#4caf50'; // Зелений для успішного збереження
        } else {
            notification.style.backgroundColor = '#f44336'; // Червоний для помилок
        }

        // Додаємо сповіщення до контейнера
        const notificationContainer = document.getElementById('notification-container');
        notificationContainer.appendChild(notification);

        // Видаляємо сповіщення через 3 секунди
        setTimeout(() => {
            notification.remove();
        }, 3000);
    }


    function showNotification(data) {
        console.log('Showing notification for:', data); // Лог для перевірки
        loadNotificationHTML((notificationElement) => {
            // Наповнення елементів даними
            notificationElement.querySelector('.Title').textContent = `Рівень ${data.currentLevel}: ${data.skillName}`;
            notificationElement.querySelector('.Description').textContent = data.skillDescription;
            notificationElement.querySelector('.AdditionalNotificationCount').textContent = `XP: ${data.newXP} / ${data.xpToNextLevel}`;

            const picElement = notificationElement.querySelector('.Pic');
            const img = document.createElement('img');
            img.src = `img/playerstats/${data.skillIcon}`;
            img.onerror = () => console.error(`Image not found: img/playerstats/${data.skillIcon}`);
            picElement.appendChild(img);

            const notificationContainer = document.getElementById('notification-container');

            // Примусове відображення контейнера, якщо він прихований
            notificationContainer.style.display = 'flex';

            // Перевірка на кількість нотифікацій
            if (notificationCount >= MAX_NOTIFICATIONS) {
                const oldestNotification = notificationContainer.firstChild;
                if (oldestNotification) {
                    oldestNotification.remove();
                    notificationCount--;
                }
            }

            notificationContainer.appendChild(notificationElement);
            adjustNotifications();
            notificationCount++;

            // Керуємо видаленням нотифікацій по черзі
            scheduleNotificationRemoval(notificationElement);
        });
    }

    function updateExperience(data) {
        if (notificationCount > 0) {
            notificationQueue.push(data); // Додаємо до черги
        } else {
            showNotification(data); // Показуємо нотифікацію
        }
    }

    function adjustNotifications() {
        const notifications = document.querySelectorAll('.SkillNotificationMarkoScripts');
        const overlap = 20; // Ступінь накладання
        const totalNotifications = notifications.length;

        notifications.forEach((notification, index) => {
            // Розташування нотифікацій зі зсувом
            notification.style.bottom = `${20 + index * overlap}px`;

            // Прозорість: найновіша (останній елемент у списку) матиме прозорість 1
            const relativeIndex = totalNotifications - index; // Навпаки: чим новіша, тим менший index
            const opacity = 1 - (relativeIndex - 1) * 0.1; // Прозорість зменшується зі збільшенням відстані від верхньої
            notification.style.opacity = Math.max(opacity, 0.3); // Мінімальна прозорість — 0.3
        });
    }

    function scheduleNotificationRemoval(notificationElement) {
        const notificationContainer = document.getElementById('notification-container');

        // Затримка перед fade-out
        setTimeout(() => {
            notificationElement.classList.add('fade-out');
            setTimeout(() => {
                notificationElement.remove();
                notificationCount--;
                adjustNotifications();

                if (notificationCount === 0) {
                    // Приховуємо контейнер, якщо більше немає нотифікацій
                    notificationContainer.style.display = 'none';
                }

                if (notificationQueue.length > 0) {
                    const nextNotification = notificationQueue.shift();
                    showNotification(nextNotification); // Відображаємо наступну нотифікацію
                }
            }, 500); // Тривалість анімації fade-out
        }, 6000 + notificationCount * 500); // Враховуємо позицію нотифікації
    }


    document.addEventListener('DOMContentLoaded', () => {
        let translations = {}; // Зберігання перекладів

        // Завантаження перекладів
        function loadTranslations(language, callback) {
            fetch(`translations/${language}.json`)
                .then((resp) => resp.json())
                .then((data) => {
                    translations = data;
                    callback();
                })
                .catch((err) => console.error('Помилка при завантаженні перекладів:', err));
        }

        // Виконання команди
        function executeCommand(command) {
            fetch(`https://${GetParentResourceName()}/executeCommand`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json; charset=UTF-8',
                },
                body: JSON.stringify({
                    command: command
                })
            }).then(resp => resp.json()).then(resp => {
                if (resp === 'ok') {
                    console.log(`Команда ${command} виконана успішно`);
                    // Закриття інтерфейсу
                    fetch(`https://${GetParentResourceName()}/closeUI`, {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json; charset=UTF-8',
                        },
                        body: JSON.stringify({})
                    }).then(resp => resp.json()).then(resp => {
                        if (resp === 'ok') {
                            console.log(translations['ui.interfaceClosed']);
                        } else {
                            console.log(translations['ui.closeError']);
                        }
                    }).catch(error => {
                        console.log(translations['ui.requestCloseError'], error);
                    });
                } else {
                    console.log(translations['ui.commandError']);
                }
            }).catch(error => {
                console.log(translations['ui.commandRequestError'], error);
            });
        }

        // Завантаження динамічних пунктів меню
        function loadDynamicMenuItems() {
            fetch(`https://${GetParentResourceName()}/getMenuItems`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json; charset=UTF-8',
                },
                body: JSON.stringify({})
            })
            .then(resp => resp.json())
            .then(menuItems => {
                const dynamicMenu = document.getElementById('dynamic-menu');
                menuItems.forEach(menuItem => {
                    if (!document.querySelector(`.menu-item[data-target="${menuItem.action}"]`)) {
                        const item = document.createElement('div');
                        item.className = 'menu-item dynamic';
                        item.setAttribute('data-target', menuItem.action);

                        item.innerHTML = `
                            <div class="icon">
                                <img src="${menuItem.icon}" alt="${menuItem.title} Icon">
                            </div>
                            <div class="menu-text">${translations[menuItem.title] || menuItem.title}</div>
                            ${menuItem.badge ? `<div class="badge">${menuItem.badge}</div>` : ''}
                        `;

                        item.addEventListener('click', () => handleDynamicAction(menuItem));
                        dynamicMenu.appendChild(item);
                    }
                });
            })
            .catch(err => console.error(translations['ui.menuLoadError'], err));
        }

        // Обробка динамічних дій
        function handleDynamicAction(menuItem) {
            switch (menuItem.actionType) {
                case 'command':
                    executeCommand(menuItem.action);
                    break;
                default:
                    console.warn(`${translations['ui.unknownActionType']}: ${menuItem.actionType}`);
            }
        }

        // Івент для відкриття інтерфейсу
        window.addEventListener('message', (event) => {
            if (event.data.type === 'open') {
                const sidebar = document.querySelector('.sidebar');
                const dynamicItems = sidebar.querySelectorAll('.menu-item.dynamic');
                dynamicItems.forEach(item => item.remove());
                loadDynamicMenuItems();
            }
        });

        // Завантаження перекладів і запуск інтерфейсу
        loadTranslations('en', () => {
            console.log(translations['ui.ready']);
        });
    });




