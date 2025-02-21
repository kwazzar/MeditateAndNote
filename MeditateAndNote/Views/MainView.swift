//
//  MainView.swift
//  MeditateAndNote
//
//  Created by Quasar on 21.02.2025.
//

import SwiftUI

struct MainView: View {
    @State private var notes: [Note] = [
        Note(title: "Заметка 1", content: "Содержание заметки 1", date: Date()),
        Note(title: "Заметка 2", content: "Содержание заметки 2", date: Date()),
        Note(title: "Заметка 3", content: "Содержание заметки 3", date: Date()),
        Note(title: "Заметка 4", content: "Содержание заметки 4", date: Date())
    ]

    var body: some View {
        VStack {
            // Cloud параметры
            CloudParametersView()

            Spacer()

            // Круглая кнопка
            Button(action: {
                // Действие при нажатии
            }) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                            .font(.system(size: 30))
                    )
                    .shadow(radius: 5)
            }

            Spacer()

            // Стопка заметок с наложением
//            ScrollView {
                ZStack {
                    ForEach(Array(notes.enumerated().reversed()), id: \.element.id) { index, note in
                        NoteCard(note: note)
                            .offset(y: CGFloat(index) * 25) // Показываем только верхний край
                            .onTapGesture {
                                // Анимация при тапе
                                withAnimation {
                                    if let noteIndex = notes.firstIndex(where: { $0.id == note.id }) {
                                        let note = notes.remove(at: noteIndex)
                                        notes.append(note)
                                    }
                                }
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, CGFloat(notes.count) * 20) // Добавляем отступ снизу для скролла
//            }
        }.background(.gray)
    }
}

// Компонент облака параметров
struct CloudParametersView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Параметры")
                .font(.title2)
                .bold()

            HStack(spacing: 20) {
                ParameterItem(title: "Параметр 1", value: "85%")
                ParameterItem(title: "Параметр 2", value: "64%")
                ParameterItem(title: "Параметр 3", value: "92%")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.gray.opacity(0.1))
            )
        }
        .padding()
    }
}

// Компонент параметра
struct ParameterItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(value)
                .font(.title3)
                .bold()
        }
    }
}

// Компонент карточки заметки
struct NoteCard: View {
    let note: Note

    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        formatter.locale = Locale(identifier: "uk_UA") // Украинская локализация
        return formatter
    }

    var body: some View {
        VStack(spacing: 0) {
            // Основное содержимое карточки
            VStack(alignment: .leading, spacing: 8) {

                Text(note.content)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding()
            .frame(height: 120) // Фиксированная высота для контента

            // Нижняя панель с датой (всегда видимая)
            HStack {
                Text(dateFormatter.string(from: note.date))
                                   .font(.caption)
                                   .foregroundColor(.gray)

                Spacer()
                Text(note.title)
                    .font(.headline)
                Spacer()

                Image(systemName: "doc.text")
                    .foregroundColor(.blue)
                #warning("кнопка перехода на заметку")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.white)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.2)),
                alignment: .top
            )
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .gray.opacity(0.2), radius: 5)
        )
    }
}

// Превью
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
