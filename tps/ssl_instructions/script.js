function showInstructions(os) {
    const instructionsDiv = document.getElementById('instructions');
    instructionsDiv.classList.add('show');
    
    if (os === 'windows-chrome') {
      instructionsDiv.innerHTML = `
        <h2>Настройка браузера Chrome в ОС Windows</h2>
        <ol>
          <li>Скачате SSL сертификат по кнопке выше на  свой компьютер (по умолчанию файл сохраняется в папку "Загрузки"). Имя скаченного файла: root-ca.crt</li>
          <li>
            Находим файл в папке и нажимаем дважды на него. Далее нажимаем кнопку "Установить сертификат"
            <img src="images/windows-1.png" class="screenshot">
          </li>
          <li>
            В окне "Мастер импорта сертификатов" -> "Расположение хранилища" выбираем "Локальный компьютер". Нажимаем кнопку "Далее".
            <img src="images/windows-2.png" class="screenshot">
          </li>
          <li>
            Далее выбираем пункт "Поместить сертификаты в следующее хранилище" и нажимаем кнопку "Обзор". Выбираем "Доверенные корневые центры" и нажимаем кнопку "ОК" и "Далее"
            <img src="images/windows-3.png" class="screenshot">
          </li>
          <li>Завершение мастера импорта сертификатов можно закрыть, нажав кнопку "Готово".</li>
          <li>Перезапустите браузер.</li>
        </ol>
      `;
    } else if (os === 'ubuntu-firefox') {
      instructionsDiv.innerHTML = `
        <h2>Настройка браузера Firefox в ОС Ubuntu/Alt Linux</h2>
        <ol>
          <li>Скачате SSL сертификат по кнопке выше на  свой компьютер.</li>
          <li>Откройте браузер Firefox</li>
          <li>
            Перейдите в настройки браузера
            <img src="images/ubuntu-firefox-1.png" class="screenshot">
          </li>
          <li>
            В строке поиска по настройкам браузера, наберите слово сертификат и нажмите кнопку "Просмотр сертификатов"
            <img src="images/ubuntu-firefox-2.png" class="screenshot">
          </li>
          <li>
            В открывшемся окне, выберите вкладку "Центры сертификации" и нажмите кнопку "Импортировать".
            <img src="images/ubuntu-firefox-3.png" class="screenshot">
          </li>
          <li>
            В новом открывшемся окне, выберите файл root-ca.crt со своего компьютера (по умолчанию файл сохраняется в папку "Загрузки").
            <img src="images/ubuntu-firefox-4.png" class="screenshot">
          </li>
          <li>
            В открывшемся окне, установите галочку "Доверять при идентификации веб-сайтов" и нажмите кнопку "ОК". В окне "Управление сертификатами" так же нажимаем кнопку "ОК"
            <img src="images/ubuntu-firefox-5.png" class="screenshot">
          </li>
          <li>Перезапустите браузер.</li>
        </ol>
      `;
    } else {
      instructionsDiv.innerHTML = `
        <h2>Настройка браузера Chrome в ОС Ubuntu/Alt Linux</h2>
        <ol>
          <li>Скачате SSL сертификат по кнопке выше на  свой компьютер.</li>
          <li>Откройте браузер Chrome</li>
          <li>
            Перейдите в настройки браузера
            <img src="images/ubuntu-chrome-1.png" class="screenshot">
          </li>
          <li>
            Выбрать пункт "Конфиенциальность и безопасность" -> "Безопасность", далее пролистать вниз и выбрать "Настроить сертификаты"
            <img src="images/ubuntu-chrome-2.png" class="screenshot">
            <img src="images/ubuntu-chrome-3.png" class="screenshot">
          </li>
          <li>
            В открывшемся окне, выберите вкладку "Центры сертификации" и нажмите кнопку "Импорт".
            <img src="images/ubuntu-chrome-4.png" class="screenshot">
          </li>
          <li>
            В новом открывшемся окне, выберите файл root-ca.crt со своего компьютера (по умолчанию файл сохраняется в папку "Загрузки").
            <img src="images/ubuntu-chrome-5.png" class="screenshot">
          </li>
          <li>
            В открывшемся окне "Центр сертификации", установите галочку "Доверять этому сертификату при идентификации сайтов" и нажмите кнопку "ОК".
            <img src="images/ubuntu-chrome-6.png" class="screenshot">
          </li>
          <li>Перезапустите браузер.</li>
        </ol>
      `;
    }
  }