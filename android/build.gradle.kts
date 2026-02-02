buildscript {
    repositories {
        // 官方仓库（优先使用）
        google()
        mavenCentral()
        
        // 国内镜像（作为备用）
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/nexus/content/groups/public") }
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.13.0") // 推荐稳定版
    }
}

allprojects {
    repositories {
        // 官方仓库（优先使用）
        google()
        mavenCentral()
        
        // 国内镜像（作为备用）
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/nexus/content/groups/public") }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
